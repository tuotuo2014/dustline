#!/usr/bin/env python3
"""Desktop room relay; exposes only health and WebSocket routes, never project files."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import signal
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
# Reuse the tested packet relay and pinned pure-Python runtime without modifying
# the independent mobile edition. The game protocol is checked by the host.
sys.path.insert(0, str(ROOT / "mobile"))
from coop_relay import handle_upgrade

STATE = ROOT / ".runtime" / "desktop-coop.json"
ADDRESS = ROOT / "当前桌面联机地址.txt"


class Handler(BaseHTTPRequestHandler):
    rbufsize = 0

    def do_GET(self):
        route = urlsplit(self.path).path
        if route == "/multiplayer":
            handle_upgrade(self)
            return
        if route == "/health.json":
            body = json.dumps({"name": "废土回响桌面联机", "protocol": 4,
                               "instance": self.server.instance}).encode()
            content_type = "application/json"
        elif route == "/":
            body = ("<!doctype html><meta charset='utf-8'><title>废土回响 · 真人组队</title>"
                    "<body style='background:#211b12;color:#f3dbab;font:20px/1.8 sans-serif;padding:8vw'>"
                    "<h1>废土回响 · 桌面真人组队</h1><p>在桌面游戏中打开「真人联机」，开启「异地组队」，"
                    "将朋友发来的完整邀请链接粘贴到加入栏。</p><p>同一 Wi-Fi 可直接使用附近房间。</p>"
                    "<p>此页面是联机入口，游戏在桌面应用中运行。</p></body>").encode()
            content_type = "text/html; charset=utf-8"
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def server_close(self):
        if hasattr(self, "relay_hub"):
            self.relay_hub.close()
        super().server_close()


def publish(url, status):
    STATE.parent.mkdir(exist_ok=True)
    data = {"url": url if status == "ready" else "", "status": status,
            "checked_at": time.time(), "pid": os.getpid()}
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(data))
    temporary.replace(STATE)
    text = ("废土回响 · 桌面真人联机\n\n服务地址：\n" + url +
            "\n\n房主在游戏中开启异地组队，使用此地址创建房间。\n"
            "复制游戏内生成的完整邀请链接给朋友。请保持本窗口和电脑运行。\n"
            "这是免费临时入口，重新启动后地址可能变化。\n") if status == "ready" else (
                "废土回响 · 桌面真人联机\n\n" +
                ("服务已关闭。" if status == "stopped" else "正在连接，请等待验证成功后显示地址。") +
                "同一 Wi-Fi 可直接使用游戏内附近房间。\n")
    if not ADDRESS.exists() or ADDRESS.read_text() != text:
        ADDRESS.write_text(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8078)
    parser.add_argument("--local-only", action="store_true")
    args = parser.parse_args()
    try:
        server = Server(("127.0.0.1", args.port), Handler)
    except OSError:
        try:
            info = json.loads(STATE.read_text())
            if info["status"] == "ready" and time.time()-info["checked_at"] < 30:
                print("桌面联机服务已运行：\n"+info["url"], flush=True)
                return
        except (OSError, ValueError, KeyError):
            pass
        raise SystemExit("联机服务端口已被使用，请检查已有的桌面联机窗口。")
    server.instance = secrets.token_hex(16)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    print(f"本地联机服务：http://127.0.0.1:{args.port}/", flush=True)
    process = None
    stopped = threading.Event()
    monitor = None
    if not args.local_only:
        publish("", "connecting")

    def stop(*_args):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        if args.local_only:
            while not stopped.wait(1):
                pass
            return
        binary = ROOT / "mobile/tools/cloudflared/cloudflared"
        if not binary.is_file():
            raise SystemExit("缺少免费联机入口工具，请查看桌面联机说明。")
        process = subprocess.Popen([str(binary), "tunnel", "--url", f"http://127.0.0.1:{args.port}",
                                    "--no-autoupdate", "--protocol", "http2"], stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1)
        shared = {"url": ""}

        def verify():
            previous = ""
            while not stopped.is_set():
                url = shared["url"]
                healthy = False
                if url:
                    try:
                        request = Request(url+"health.json", headers={"Cache-Control": "no-cache"})
                        with urlopen(request, timeout=5) as response:
                            info = json.load(response)
                            healthy = response.status == 200 and info.get("instance") == server.instance
                    except (OSError, ValueError):
                        pass
                publish(url, "ready" if healthy else "connecting")
                if healthy and previous != url:
                    print("\n公网入口已验证。房主在桌面游戏中粘贴：\n"+url, flush=True)
                previous = url if healthy else ""
                stopped.wait(5)

        monitor = threading.Thread(target=verify, daemon=True)
        monitor.start()
        with (STATE.parent / "desktop-tunnel.log").open("w") as log:
            for line in process.stdout:
                log.write(line)
                log.flush()
                match = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", line)
                if match:
                    shared["url"] = match.group(0)+"/"
            process.wait()
        print("公网入口进程已结束，请重新打开启动器。", flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        stopped.set()
        if monitor:
            monitor.join(timeout=7)
        if not args.local_only:
            publish("", "stopped")
        if process and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
