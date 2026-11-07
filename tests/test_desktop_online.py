"""The public room endpoint must never serve project files or directory listings."""
from importlib.util import module_from_spec, spec_from_file_location
import json
from pathlib import Path
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
spec = spec_from_file_location("desktop_online", ROOT / "tools/desktop_online.py")
online = module_from_spec(spec)
spec.loader.exec_module(online)


class DesktopEntry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = online.Server(("127.0.0.1", 0), online.Handler)
        cls.server.instance = "test-owned-instance"
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def test_health_identifies_actual_server(self):
        with urlopen(self.base+"/health.json") as response:
            health = json.load(response)
        self.assertEqual(health["instance"], "test-owned-instance")
        self.assertEqual(health["protocol"], 4)

    def test_landing_explains_desktop_entry(self):
        with urlopen(self.base+"/?room=ABCDEF") as response:
            self.assertIn("桌面游戏", response.read().decode())

    def test_source_and_proxy_routes_are_not_public(self):
        for route in ["/project.godot", "/main.gd", "/.runtime/desktop-proxy.json",
                      "/../main.gd", "/mobile/", "/proxy", "/bridge/test/123"]:
            with self.subTest(route=route), self.assertRaises(HTTPError) as error:
                urlopen(self.base+route)
            self.assertEqual(error.exception.code, 404)

    def test_relay_requires_websocket_handshake(self):
        with self.assertRaises(HTTPError) as error:
            urlopen(self.base+"/multiplayer")
        self.assertEqual(error.exception.code, 426)


if __name__ == "__main__":
    unittest.main()
