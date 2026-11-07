#!/usr/bin/env python3
"""Serve only the mobile export, with a browser-aware HTTPS entry bridge."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import gzip
import re
import socket
import subprocess
import sys
import time
from urllib.parse import unquote, urlsplit

MOBILE_DIR = Path(__file__).resolve().parent
CONNECTION_FILE = MOBILE_DIR / "builds" / "https_connection.json"
CACHE_DIR = MOBILE_DIR / "builds" / "web-compressed"
# Also supports tests that load this module by filename.
if str(MOBILE_DIR) not in sys.path:
    sys.path.insert(0, str(MOBILE_DIR))
from coop_relay import PATH as MULTIPLAYER_PATH, handle_upgrade


class MobileHTTPServer(ThreadingHTTPServer):
    def server_close(self):
        if hasattr(self, "relay_hub"):
            self.relay_hub.close()
        super().server_close()


def prepare_compressed_assets():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    for name in ["index.wasm", "index.pck", "index.js"]:
        source = MOBILE_DIR / "builds" / "web" / name
        target = CACHE_DIR / (name + ".gz")
        if source.is_file() and (not target.is_file() or target.stat().st_mtime_ns < source.stat().st_mtime_ns):
            temp = target.with_suffix(".tmp")
            temp.write_bytes(gzip.compress(source.read_bytes(), compresslevel=6, mtime=0))
            temp.replace(target)


CONNECTION_FRESH_SECONDS = 30


def connection():
    empty = {"url": "", "name": "废土回响", "status": "connecting"}
    try:
        value = json.loads(CONNECTION_FILE.read_text())
        if not isinstance(value, dict):
            return empty
        url = value.get("url", "")
        status = value.get("status", "connecting")
        if status not in ("ready", "connecting", "reconnecting", "stopped"):
            status = "connecting"
        now = time.time()
        checked_at = value.get("checked_at", 0)
        healthy_at = value.get("last_health_at", 0)
        fresh = (isinstance(checked_at, (int, float)) and isinstance(healthy_at, (int, float))
                 and 0 <= now - checked_at <= CONNECTION_FRESH_SECONDS
                 and 0 <= now - healthy_at <= CONNECTION_FRESH_SECONDS)
        if status == "ready" and fresh and isinstance(url, str) and re.fullmatch(r"https://[a-z0-9-]+\.trycloudflare\.com/?", url):
            return {"url": url, "name": "废土回响", "status": "ready"}
        return {"url": "", "name": "废土回响", "status": "reconnecting" if status == "ready" else status}
    except (OSError, ValueError, TypeError):
        return empty


HTTPS_BRIDGE = '''<script>
document.addEventListener('DOMContentLoaded', () => {
if (!window.isSecureContext) {
  document.body.innerHTML = '<div style="margin:0;background:#211b12;color:#f3dbab;font:20px/1.7 sans-serif;display:grid;place-items:center;min-height:100vh"><main style="max-width:540px;padding:32px"><h1>废土回响</h1><p id="connection-note">正在连接手机游戏入口…</p><a id="secure-link" hidden style="color:#ffda79">进入游戏 →</a><p style="font-size:15px;opacity:.7">请保持电脑上的手机版启动窗口开启。</p></main></div>';
  const connect = async () => {
    try {
      const info = await fetch('/connection.json', {cache:'no-store'}).then(r=>r.json());
      if (info.status === 'ready' && info.url && /^https:\/\/[a-z0-9-]+\.trycloudflare\.com\/?$/.test(info.url)) {
        const link=document.getElementById('secure-link');
        link.href=info.url; link.hidden=false;
        document.getElementById('connection-note').textContent='正在进入安全连接…';
        location.replace(info.url);
        return;
      }
      document.getElementById('secure-link').hidden=true;
      document.getElementById('connection-note').textContent = info.status === 'reconnecting' ? '手机入口连接中断，正在自动重连。请保持电脑联网并唤醒，本页会自动重试。' : '手机入口尚未连接。请在电脑打开「打开手机版」并等待连接成功，本页会自动重试。';
    } catch (_) {
      document.getElementById('secure-link').hidden=true;
      document.getElementById('connection-note').textContent='无法连接电脑上的游戏服务。请保持电脑联网并唤醒，本页会自动重试。';
    }
    setTimeout(connect,3000);
  };
  connect();
}
});
</script>'''


class MobileHandler(SimpleHTTPRequestHandler):
    rbufsize = 0  # WebSocket traffic must not remain in an HTTP read buffer.

    def do_GET(self):
        if urlsplit(self.path).path == MULTIPLAYER_PATH:
            handle_upgrade(self)
            return
        super().do_GET()

    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def list_directory(self, path):
        self.send_error(404)
        return None

    def send_head(self):
        route = unquote(urlsplit(self.path).path)
        if route == "/health.json":
            return self._bytes(json.dumps({"name": "废土回响", "instance": getattr(self.server, "instance_token", "")}, ensure_ascii=False).encode(), "application/json; charset=utf-8")
        if route == "/connection.json":
            return self._bytes(json.dumps(connection(), ensure_ascii=False).encode(), "application/json; charset=utf-8")
        filename = "index.html" if route == "/" else route.lstrip("/")
        # Export assets only: no project source, tools, directory listing, or symlinks.
        allowed = {"index.html", "index.js", "index.wasm", "index.pck", "index.png", "index.icon.png", "index.apple-touch-icon.png", "index.audio.worklet.js", "index.audio.position.worklet.js"}
        target = Path(self.directory) / filename
        if filename not in allowed or not target.is_file() or target.is_symlink():
            self.send_error(404)
            return None
        if filename == "index.html":
            html = target.read_text()
            html = html.replace("<head>", "<head>\n" + HTTPS_BRIDGE, 1)
            html = html.replace("const statusOverlay = document.getElementById('status');", "if (!window.isSecureContext) return;\n\tconst statusOverlay = document.getElementById('status');", 1)
            html = html.replace('src="index.png"', 'src="index.icon.png"')
            html = html.replace('<progress id="status-progress"></progress>', '<progress id="status-progress"></progress><p id="loading-copy" style="position:absolute;bottom:17%;width:100%;text-align:center;color:#f3dbab;font:18px/1.6 sans-serif">废土回响 · 正在准备游戏，请稍候…</p>')
            html = html.replace('statusProgress.value = current;', "const loadingCopy = document.getElementById('loading-copy'); if (loadingCopy) loadingCopy.textContent = current < total ? '正在下载游戏 · ' + Math.round(current / total * 100) + '%' : '资源已就绪 · 正在生成荒原场景，请稍候…';\n\t\t\t\t\tstatusProgress.value = current;")
            return self._bytes(html.encode(), "text/html; charset=utf-8")
        compressed = CACHE_DIR / (filename + ".gz")
        if ("gzip" in self.headers.get("Accept-Encoding", "") and compressed.is_file()
                and compressed.stat().st_mtime_ns >= target.stat().st_mtime_ns):
            self.send_response(200)
            self.send_header("Content-Type", self.guess_type(str(target)))
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Vary", "Accept-Encoding")
            self.send_header("Content-Length", str(compressed.stat().st_size))
            self.end_headers()
            return compressed.open("rb")
        return super().send_head()

    def copyfile(self, source, outputfile):
        # Bound large concurrent transfers so the tunnel cannot overrun the
        # system network buffer while serving the engine and game pack together.
        block_size = 32 * 1024
        rate = 1024 * 1024
        started = time.monotonic()
        sent = 0
        try:
            while chunk := source.read(block_size):
                outputfile.write(chunk)
                sent += len(chunk)
                delay = sent / rate - (time.monotonic() - started)
                if delay > 0:
                    time.sleep(min(delay, .05))
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _bytes(self, data, content_type):
        from io import BytesIO
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        return BytesIO(data)


def local_addresses():
    addresses = set()
    for interface in ("en0", "en1"):
        try:
            value = subprocess.check_output(["/usr/sbin/ipconfig", "getifaddr", interface], text=True, stderr=subprocess.DEVNULL).strip()
            if value:
                addresses.add(value)
        except (OSError, subprocess.CalledProcessError):
            pass
    try:
        for value in socket.gethostbyname_ex(socket.gethostname())[2]:
            if not value.startswith("127."):
                addresses.add(value)
    except OSError:
        pass
    return sorted(addresses)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8077)
    args = parser.parse_args()
    export_dir = Path(__file__).resolve().parent / "builds" / "web"
    if not (export_dir / "index.html").is_file():
        raise SystemExit("请先运行 mobile/build_mobile.sh web 生成手机版网页。")
    prepare_compressed_assets()
    server = MobileHTTPServer(("0.0.0.0", args.port), partial(MobileHandler, directory=str(export_dir)))
    print("本地游戏服务已启动。手机请使用 HTTPS 入口。", flush=True)
    for address in local_addresses():
        print(f"局域网引导页：http://{address}:{args.port}/", flush=True)
    print(f"电脑预览：http://localhost:{args.port}/", flush=True)
    print("此窗口保持打开。按 Control+C 关闭。首次加载需要下载完整游戏资源。", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n手机版服务器已关闭。")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
