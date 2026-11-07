"""HTTP entry regression tests; temporary loopback server, no game/GPU/tunnel.

Run with: python3 mobile/tests/test_https_entry.py
The bridge execution checks use Node when installed (or NODE_BINARY is set).
"""
from functools import partial
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
import importlib.util
import gzip
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import time
import unittest

MOBILE_DIR = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("mobile_https_server", MOBILE_DIR / "serve_mobile.py")
SERVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVER)
NODE = os.environ.get("NODE_BINARY") or shutil.which("node")
if not NODE:
    bundled = Path.home() / ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
    NODE = str(bundled) if bundled.is_file() else None


class QuietHandler(SERVER.MobileHandler):
    def log_message(self, *_args):
        pass


class EntryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dustline-https-test-")
        self.root = Path(self.temp.name)
        self.exports = self.root / "web"
        self.exports.mkdir()
        self.metadata = self.root / "connection.json"
        self.old_metadata = SERVER.CONNECTION_FILE
        self.old_cache = SERVER.CACHE_DIR
        SERVER.CONNECTION_FILE = self.metadata
        SERVER.CACHE_DIR = self.root / "compressed"
        SERVER.CACHE_DIR.mkdir()
        # Exercise the currently exported Godot shell so shell changes cannot
        # silently disable the guard while an idealized fixture keeps passing.
        self.exports.joinpath("index.html").write_text(
            (MOBILE_DIR / "builds/web/index.html").read_text())
        self.exports.joinpath("index.wasm").write_bytes(b"\0asm\x01\0\0\0")
        self.exports.joinpath("index.pck").write_bytes(b"test-game-pack")
        self.exports.joinpath("index.js").write_text("/* test engine asset */")
        self.server = ThreadingHTTPServer(
            ("127.0.0.1", 0), partial(QuietHandler, directory=str(self.exports)))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        SERVER.CONNECTION_FILE = self.old_metadata
        SERVER.CACHE_DIR = self.old_cache
        self.temp.cleanup()

    def request(self, path="/", method="GET", headers=None):
        client = HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        try:
            client.request(method, path, headers=headers or {})
            response = client.getresponse()
            return response.status, {key.lower(): value for key, value in response.getheaders()}, response.read()
        finally:
            client.close()

    def test_connection_missing_and_valid(self):
        status, headers, body = self.request("/connection.json")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["url"], "")
        self.assertEqual(headers["cache-control"], "no-store")
        url = "https://valid-game.trycloudflare.com/"
        self.metadata.write_text(json.dumps({"url": url, "status": "ready", "checked_at": time.time(), "last_health_at": time.time(), "private": "must-not-leak"}))
        self.assertEqual(json.loads(self.request("/connection.json")[2]),
                         {"url": url, "name": "废土回响", "status": "ready"})

    def test_corrupt_or_non_object_metadata_falls_back(self):
        for value in ["{broken", "null", "[]", '"text"', "42", '{"url": 3}']:
            with self.subTest(value=value):
                self.metadata.write_text(value)
                self.assertEqual(SERVER.connection(), {"url": "", "name": "废土回响", "status": "connecting"})

    def test_unapproved_redirect_destinations_are_rejected(self):
        for url in ["http://valid.trycloudflare.com", "https://example.com/",
                    "https://valid.trycloudflare.com.evil.example/",
                    "https://valid.trycloudflare.com/secret", "javascript:alert(1)"]:
            with self.subTest(url=url):
                self.metadata.write_text(json.dumps({"url": url, "status": "ready", "checked_at": time.time(), "last_health_at": time.time()}))
                self.assertEqual(json.loads(self.request("/connection.json")[2])["url"], "")

    def test_stale_sleep_or_unverified_metadata_never_redirects(self):
        url = "https://valid-game.trycloudflare.com/"
        for value in [
                {"url": url},
                {"url": url, "status": "ready", "checked_at": time.time() - 90, "last_health_at": time.time() - 90},
                {"url": url, "status": "ready", "checked_at": time.time(), "last_health_at": time.time() - 90},
                {"url": url, "status": "ready", "checked_at": time.time() + 90, "last_health_at": time.time() + 90},
                {"url": url, "status": "reconnecting", "checked_at": time.time(), "last_health_at": time.time()},
                {"url": url, "status": "ready", "checked_at": "bad", "last_health_at": time.time()}]:
            with self.subTest(value=value):
                self.metadata.write_text(json.dumps(value))
                self.assertEqual(json.loads(self.request("/connection.json")[2])["url"], "")
        result = self.browser(False, {"url": url, "status": "reconnecting"})
        self.assertEqual(result["redirected"], "")
        self.assertIn("正在自动重连", result["notice"])

    def test_health_endpoint_only_returns_launch_identity(self):
        self.server.instance_token = "this-launch"
        status, headers, body = self.request("/health.json?check=123")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {"name": "废土回响", "instance": "this-launch"})
        self.assertEqual(headers["cache-control"], "no-store")

    def test_asset_get_head_and_mime(self):
        for asset, mime in [("index.wasm", "application/wasm"),
                            ("index.pck", "application/octet-stream")]:
            with self.subTest(asset=asset):
                status, headers, body = self.request("/" + asset + "?v=2")
                self.assertEqual(status, 200)
                self.assertEqual(headers["content-type"], mime)
                self.assertEqual(body, self.exports.joinpath(asset).read_bytes())
                status, head, body = self.request("/" + asset, "HEAD")
                self.assertEqual(status, 200)
                self.assertEqual(head["content-type"], mime)
                self.assertEqual(int(head["content-length"]), self.exports.joinpath(asset).stat().st_size)
                self.assertEqual(body, b"")
                self.assertEqual(head["x-content-type-options"], "nosniff")

    def test_no_source_directories_traversal_or_symlinks(self):
        self.exports.joinpath("project").mkdir()
        self.exports.joinpath("project/project.godot").write_text("private-project")
        self.exports.joinpath(".env").write_text("private-secret")
        self.root.joinpath("serve_mobile.py").write_text("private-source")
        self.exports.joinpath("index.png").symlink_to(self.root / "serve_mobile.py")
        for path in ["/project/", "/project/project.godot", "/tools/", "/.env",
                     "/../serve_mobile.py", "/%2e%2e/serve_mobile.py",
                     "/%2eenv", "/index.png", "/unknown.js"]:
            with self.subTest(path=path):
                status, _, body = self.request(path)
                self.assertEqual(status, 404)
                self.assertNotIn(b"private-", body)

    def test_compression_negotiation_and_content(self):
        original = self.exports.joinpath("index.wasm").read_bytes()
        compressed = gzip.compress(original)
        SERVER.CACHE_DIR.joinpath("index.wasm.gz").write_bytes(compressed)
        status, headers, body = self.request("/index.wasm", headers={"Accept-Encoding": "gzip, br"})
        self.assertEqual(status, 200)
        self.assertEqual(headers["content-type"], "application/wasm")
        self.assertEqual(headers["content-encoding"], "gzip")
        self.assertEqual(headers["vary"], "Accept-Encoding")
        self.assertEqual(gzip.decompress(body), original)
        status, headers, body = self.request("/index.wasm", "HEAD", {"Accept-Encoding": "gzip"})
        self.assertEqual(status, 200)
        self.assertEqual(int(headers["content-length"]), len(compressed))
        self.assertEqual(body, b"")
        status, headers, body = self.request("/index.wasm", headers={"Accept-Encoding": "identity"})
        self.assertEqual(status, 200)
        self.assertNotIn("content-encoding", headers)
        self.assertEqual(body, original)

    def browser(self, secure, metadata):
        if not NODE:
            self.skipTest("Node required for JavaScript bootstrap behavior check")
        status, headers, body = self.request("/")
        self.assertEqual(status, 200)
        self.assertEqual(int(headers["content-length"]), len(body))
        script = r"""
const vm = require('node:vm');
const fs = require('node:fs');
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
const result = {starts:0, checks:0, redirected:'', retries:0, removed:false};
const events = [], nodes = new Map();
const makeNode = () => ({style:{}, children:[], lastChild:null,
  appendChild(x){this.children.push(x)}, removeAttribute(){},
  remove(){result.removed=true}});
const document = {
  body: {innerHTML:'original'},
  addEventListener(name, fn){if(name==='DOMContentLoaded') events.push(fn)},
  getElementById(id){if(!nodes.has(id)) nodes.set(id,makeNode());return nodes.get(id)},
  querySelector(){return null}, createElement:makeNode, createTextNode:x=>x
};
document.body.appendChild = () => {};
class Engine {
  startGame(){result.starts++;return Promise.resolve()}
  static getMissingFeatures(){result.checks++;return []}
}
const context = vm.createContext({window:{isSecureContext:input.secure},
  document, Engine, console, navigator:{},
  fetch:async()=>({json:async()=>input.metadata}),
  location:{replace:url=>result.redirected=url},
  setTimeout:()=>{result.retries++}});
(async()=>{
  for (const script of input.html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) {
    vm.runInContext(script[1], context, {timeout:1000});
  }
  for(const fn of events) fn();
  for(let i=0;i<12;i++) await Promise.resolve();
  result.notice = nodes.get('connection-note')?.textContent || '';
  process.stdout.write(JSON.stringify(result));
})().catch(err=>{console.error(err);process.exitCode=1});
"""
        run = subprocess.run([NODE, "-e", script],
                             input=json.dumps({"secure": secure, "metadata": metadata,
                                               "html": body.decode()}),
                             text=True, capture_output=True, timeout=5)
        self.assertEqual(run.returncode, 0, run.stderr)
        return json.loads(run.stdout)

    def test_insecure_entry_redirects_without_starting_godot(self):
        url = "https://valid-game.trycloudflare.com/"
        result = self.browser(False, {"url": url, "status": "ready"})
        self.assertEqual(result["redirected"], url)
        self.assertEqual(result["checks"], 0)
        self.assertEqual(result["starts"], 0)

    def test_insecure_entry_waits_for_tunnel_and_rejects_bad_url(self):
        for metadata in [{"url": ""}, {"url": "https://example.com/"}]:
            with self.subTest(metadata=metadata):
                result = self.browser(False, metadata)
                self.assertEqual(result["redirected"], "")
                self.assertEqual(result["starts"], 0)
                self.assertGreater(result["retries"], 0)
                self.assertIn("尚未连接", result["notice"])

    def test_secure_entry_starts_godot_without_redirect_loop(self):
        result = self.browser(True, {"url": "https://valid-game.trycloudflare.com/", "status": "ready"})
        self.assertEqual(result["redirected"], "")
        self.assertEqual(result["checks"], 1)
        self.assertEqual(result["starts"], 1)
        self.assertTrue(result["removed"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
