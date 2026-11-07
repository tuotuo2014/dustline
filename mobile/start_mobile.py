#!/usr/bin/env python3
"""Start the game plus a free HTTPS phone link, without changing the desktop game."""
from functools import partial
from pathlib import Path
import json
import re
import secrets
import signal
import subprocess
import threading
import time
from urllib.request import Request, urlopen

from serve_mobile import CONNECTION_FILE, MOBILE_DIR, MobileHandler, MobileHTTPServer, prepare_compressed_assets


class TunnelStatus:
    """Publish a short-lived link only after the tunnel reaches this server."""
    def __init__(self, instance, metadata=CONNECTION_FILE, address_file=None, probe=None):
        self.instance = instance
        self.metadata = Path(metadata)
        self.address_file = Path(address_file) if address_file else MOBILE_DIR / "当前手机网址.txt"
        self.probe = probe or self._probe
        self.lock = threading.RLock()
        self.url = ""
        self.metrics_url = ""
        self.registered = False
        self.was_ready = False
        self.last_health_at = 0.0
        self.last_notice = None
        self.publish(False)

    def publish(self, ready, stopped=False):
        with self.lock:
            now = time.time()
            status = "stopped" if stopped else ("ready" if ready else ("reconnecting" if self.was_ready else "connecting"))
            if ready:
                self.was_ready = True
                self.last_health_at = now
            value = {"url": self.url if ready else "", "name": "废土回响", "status": status,
                     "checked_at": now, "last_health_at": self.last_health_at}
            self.metadata.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.metadata.with_suffix(".tmp")
            temporary.write_text(json.dumps(value, ensure_ascii=False))
            temporary.replace(self.metadata)
            notice = (status, value["url"])
            if notice != self.last_notice:
                self.last_notice = notice
                if ready:
                    text = ("废土回响\n\n手机横屏打开：\n" + self.url +
                            "\n\n请保持电脑及启动窗口开启。电脑休眠或断网时入口会中断。临时地址在下次启动时可能变化。\n")
                    print("\n手机入口连接已验证，Safari 或 Chrome 横屏打开：\n" + self.url, flush=True)
                else:
                    text = ("废土回响\n\n" + ("手机入口已关闭。请重新双击「打开手机版」。" if stopped else
                            "手机入口暂未连通，正在等待网络恢复。请保持电脑及启动窗口开启，连接成功后这里会显示可用网址。") + "\n")
                    if not stopped:
                        print("手机入口暂未连通，正在等待网络恢复；连接成功后会显示可用网址。", flush=True)
                self.address_file.write_text(text)

    def observe(self, line):
        with self.lock:
            match = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", line)
            if match:
                self.url = match.group(0) + "/"
            metrics = re.search(r"Starting metrics server on (127\.0\.0\.1:\d+)", line)
            if metrics:
                self.metrics_url = "http://" + metrics.group(1) + "/ready"
            if "Registered tunnel connection" in line:
                self.registered = True
            elif any(message in line.lower() for message in (
                    "unregistered tunnel connection", "connection terminated", "retrying connection",
                    "failed to serve tunnel connection", "serve tunnel error", "stopping tunnel server")):
                self.registered = False
                self.publish(False)

    def _probe(self, metrics_url, url):
        # /ready reflects the live edge connection, including failures after sleep.
        # A second probe verifies the public HTTPS route reaches THIS launcher,
        # rather than treating an assigned hostname or old registration as ready.
        with urlopen(metrics_url, timeout=2) as response:
            if response.status != 200:
                return False
        request = Request(url + "health.json?check=" + str(time.time_ns()),
                          headers={"Cache-Control": "no-cache"})
        with urlopen(request, timeout=5) as response:
            health = json.loads(response.read(4096))
            return response.status == 200 and isinstance(health, dict) and health.get("instance") == self.instance

    def check(self):
        with self.lock:
            url, metrics_url, registered = self.url, self.metrics_url, self.registered
        ready = False
        if url and metrics_url and registered:
            try:
                ready = self.probe(metrics_url, url)
            except (OSError, ValueError, TypeError):
                pass
        with self.lock:
            # A log-reported disconnect during the probe must win the race.
            ready = bool(ready and registered and self.registered and url == self.url)
            self.publish(ready)
        return ready

    def monitor(self, stopped):
        while not stopped.is_set():
            self.check()
            stopped.wait(5)


def main():
    port = 8077
    export_dir = MOBILE_DIR / "builds" / "web"
    binary = MOBILE_DIR / "tools" / "cloudflared" / "cloudflared"
    if not binary.is_file() or not (export_dir / "index.html").is_file():
        raise SystemExit("缺少手机版文件，请查看 BUILDING.md。")
    prepare_compressed_assets()
    try:
        server = MobileHTTPServer(("0.0.0.0", port), partial(MobileHandler, directory=str(export_dir)))
    except OSError:
        try:
            with urlopen(f"http://localhost:{port}/connection.json", timeout=3) as response:
                current = json.load(response)
            if current.get("status") == "ready" and current.get("url", "").startswith("https://"):
                print("废土回响已在运行。手机打开：\n" + current["url"], flush=True)
                print("请保持原先的启动窗口开启。", flush=True)
                return
            if current.get("status") in ("connecting", "reconnecting"):
                print("手机版启动窗口正在连接网络，请保持原窗口开启，等待可用网址。", flush=True)
                return
        except (OSError, ValueError):
            pass
        raise SystemExit("8077 端口正在使用。请先关闭旧的手机版启动窗口，再重新打开。")
    CONNECTION_FILE.parent.mkdir(parents=True, exist_ok=True)
    CONNECTION_FILE.unlink(missing_ok=True)
    server.instance_token = secrets.token_urlsafe(24)
    status = TunnelStatus(server.instance_token)
    monitor_stop = threading.Event()
    monitor = threading.Thread(target=status.monitor, args=(monitor_stop,), daemon=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    log_path = MOBILE_DIR / "builds" / "logs" / "https-tunnel.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    print("废土回响：正在建立手机 HTTPS 入口，请稍候…", flush=True)
    try:
        process = subprocess.Popen([str(binary), "tunnel", "--url", f"http://127.0.0.1:{port}",
                                    "--no-autoupdate", "--protocol", "http2"],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, bufsize=1)
    except OSError as error:
        status.publish(False, stopped=True)
        CONNECTION_FILE.unlink(missing_ok=True)
        server.shutdown()
        server.server_close()
        raise SystemExit("手机入口启动失败，请检查 builds/logs/https-tunnel.log。") from error
    monitor.start()

    def stop(_signal=None, _frame=None):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop)
    try:
        with log_path.open("w") as log:
            for line in process.stdout:
                log.write(line)
                log.flush()
                status.observe(line)
            process.wait()
            if process.returncode:
                print("手机入口连接失败，详情见 builds/logs/https-tunnel.log。", flush=True)
    except KeyboardInterrupt:
        print("\n正在关闭手机版入口…", flush=True)
    finally:
        monitor_stop.set()
        monitor.join(timeout=8)
        status.publish(False, stopped=True)
        CONNECTION_FILE.unlink(missing_ok=True)
        if process.poll() is None:
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
