#!/usr/bin/env python3
"""Local WebSocket bridge for native Godot on Macs using a system HTTPS proxy.

Godot's WebSocketPeer doesn't expose a proxy option. This loopback-only bridge
uses the existing system proxy for CONNECT, verifies remote TLS certificates,
and forwards the WebSocket handshake and frames without interpreting game data.
"""
import http.client
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import select
import ssl
import threading
import time
from urllib.parse import urlsplit
from urllib.request import getproxies

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / ".runtime/desktop-proxy.json"


def trace(message):
    with (ROOT / ".runtime/desktop-proxy.log").open("a") as log:
        log.write(f"{time.time():.3f} {message}\n")


class Handler(BaseHTTPRequestHandler):
    rbufsize = 0

    def do_GET(self):
        prefix = "/bridge/"+self.server.token+"/"
        if not self.path.startswith(prefix) or self.headers.get("Upgrade", "").lower() != "websocket":
            self.send_error(404)
            return
        try:
            encoded = self.path[len(prefix):]
            if len(encoded) > 2048:
                raise ValueError()
            target = urlsplit(bytes.fromhex(encoded).decode())
            if target.scheme != "wss" or not target.hostname or target.username or target.password or target.port not in (None, 443):
                raise ValueError()
            proxy = self.server.proxy
            upstream = http.client.HTTPSConnection(proxy.hostname, proxy.port or 80, timeout=20)
            upstream.set_tunnel(target.hostname, 443)
            upstream.connect()
            remote = upstream.sock
            route = target.path or "/"
            if target.query:
                route += "?"+target.query
            request = f"GET {route} HTTP/1.1\r\nHost: {target.hostname}\r\n"
            for key, value in self.headers.items():
                if key.lower() not in ("host", "proxy-authorization", "proxy-connection"):
                    request += f"{key}: {value}\r\n"
            remote.sendall((request+"\r\n").encode("latin-1"))
            self.close_connection = True
            self.server.active += 1
            try:
                remote.setblocking(False)
                self.connection.setblocking(False)
                outgoing = {remote: deque(), self.connection: deque()}
                queued_bytes = {remote: 0, self.connection: 0}
                trace("bridge opened")
                while True:
                    self.server.last_use = time.monotonic()
                    readable, writable, _ = select.select([self.connection, remote],
                                                         [sock for sock, data in outgoing.items() if data], [], .1)
                    if remote.pending() and remote not in readable:
                        readable.append(remote)
                    for source in readable:
                        try:
                            payload = source.recv(65536)
                        except (BlockingIOError, ssl.SSLWantReadError, ssl.SSLWantWriteError):
                            continue
                        if not payload:
                            trace("upstream closed" if source is remote else "client closed")
                            return
                        destination = remote if source is self.connection else self.connection
                        outgoing[destination].append(payload)
                        queued_bytes[destination] += len(payload)
                        if queued_bytes[destination] > 4*1024*1024:
                            trace("queue overflow")
                            return
                    for destination in writable:
                        try:
                            # Keep the same immutable front chunk across SSLWantWrite;
                            # changing its length on a retry can abort a TLS stream.
                            chunk = outgoing[destination][0]
                            sent = destination.send(chunk)
                            queued_bytes[destination] -= sent
                            if sent == len(chunk):
                                outgoing[destination].popleft()
                            elif sent:
                                outgoing[destination][0] = chunk[sent:]
                        except (BlockingIOError, ssl.SSLWantReadError, ssl.SSLWantWriteError):
                            pass
            finally:
                self.server.active -= 1
                upstream.close()
        except (OSError, ValueError, UnicodeError, http.client.HTTPException) as error:
            trace("bridge error: "+type(error).__name__+" "+str(error))
            self.close_connection = True

    def log_message(self, *_args):
        pass


def main():
    value = getproxies().get("https", "")
    proxy = urlsplit(value if "://" in value else "http://"+value)
    if not proxy.hostname or proxy.username or proxy.password:
        return
    try:
        server = ThreadingHTTPServer(("127.0.0.1", 8076), Handler)
    except OSError:
        return
    server.daemon_threads = True
    server.proxy = proxy
    server.token = secrets.token_urlsafe(24)
    server.active = 0
    server.last_use = time.monotonic()
    STATE.parent.mkdir(exist_ok=True)
    def publish():
        temporary = STATE.with_suffix(".tmp")
        temporary.write_text(json.dumps({"pid": os.getpid(), "checked_at": time.time(),
                                        "prefix": f"ws://127.0.0.1:8076/bridge/{server.token}/"}))
        temporary.replace(STATE)
    publish()
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        while server.active or time.monotonic()-server.last_use < 120:
            publish()
            time.sleep(2)
    finally:
        server.shutdown()
        server.server_close()
        try:
            if json.loads(STATE.read_text()).get("pid") == os.getpid():
                STATE.unlink()
        except (OSError, ValueError):
            pass


if __name__ == "__main__":
    main()
