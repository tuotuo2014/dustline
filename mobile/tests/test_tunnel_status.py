"""Launcher health transitions; no real tunnel or production service needed."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

MOBILE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MOBILE))
from start_mobile import TunnelStatus


class TunnelStatusTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dustline-tunnel-status-")
        self.root = Path(self.temp.name)
        self.health = True
        self.probes = []
        def probe(metrics, url):
            self.probes.append((metrics, url))
            return self.health
        self.state = TunnelStatus("test-instance", self.root / "connection.json", self.root / "address.txt", probe)

    def tearDown(self):
        self.temp.cleanup()

    def value(self):
        return json.loads(self.state.metadata.read_text())

    def registered(self):
        self.state.observe("https://valid-game.trycloudflare.com")
        self.state.observe("Starting metrics server on 127.0.0.1:20241/metrics")
        self.state.observe("Registered tunnel connection connIndex=0")

    def test_assigned_url_and_registration_do_not_claim_ready(self):
        self.registered()
        self.assertEqual(self.value()["url"], "")
        self.assertEqual(self.value()["status"], "connecting")
        self.assertNotIn("https://", self.state.address_file.read_text())
        self.state.check()
        self.assertEqual(self.value()["status"], "ready")
        self.assertEqual(self.value()["url"], "https://valid-game.trycloudflare.com/")
        self.assertEqual(self.probes, [("http://127.0.0.1:20241/ready", "https://valid-game.trycloudflare.com/")])
        self.assertGreater(self.value()["last_health_at"], 0)

    def test_disconnect_immediately_withdraws_link_and_recovery_reuses_it(self):
        self.registered()
        self.state.check()
        self.state.observe("ERR Connection terminated connIndex=0")
        self.assertEqual(self.value()["status"], "reconnecting")
        self.assertEqual(self.value()["url"], "")
        self.assertNotIn("https://", self.state.address_file.read_text())
        self.state.check()
        self.assertEqual(len(self.probes), 1)
        self.state.observe("Registered tunnel connection connIndex=0")
        self.state.check()
        self.assertEqual(self.value()["url"], "https://valid-game.trycloudflare.com/")

    def test_health_failure_and_recovery_without_new_registration(self):
        self.registered()
        self.state.check()
        self.health = False
        self.state.check()
        self.assertEqual(self.value()["status"], "reconnecting")
        self.assertEqual(self.value()["url"], "")
        self.health = True
        self.state.check()
        self.assertEqual(self.value()["status"], "ready")
        self.state.publish(False, stopped=True)
        self.assertEqual(self.value()["status"], "stopped")
        self.assertEqual(self.value()["url"], "")

    def test_unrelated_request_error_does_not_drop_registered_tunnel(self):
        self.registered()
        self.state.observe('ERR Request failed error="stream closed" dest=/index.pck')
        self.state.check()
        self.assertEqual(self.value()["status"], "ready")

    def test_probe_failure_is_recoverable_and_disconnect_wins_race(self):
        self.registered()
        def unavailable(_metrics, _url):
            raise OSError("temporary network failure")
        self.state.probe = unavailable
        self.assertFalse(self.state.check())
        self.assertEqual(self.value()["url"], "")
        def disconnected(_metrics, _url):
            self.state.observe("Retrying connection in up to 1s")
            return True
        self.state.probe = disconnected
        self.assertFalse(self.state.check())
        self.assertEqual(self.value()["url"], "")

    def test_probe_requires_public_response_from_current_launch(self):
        class Response:
            status = 200
            def __init__(self, body=b""): self.body = body
            def __enter__(self): return self
            def __exit__(self, *_args): pass
            def read(self, _size): return self.body
        for instance, expected in [("test-instance", True), ("old-instance", False)]:
            with self.subTest(instance=instance):
                with patch("start_mobile.urlopen", side_effect=[Response(), Response(json.dumps({"instance": instance}).encode())]) as opener:
                    self.assertEqual(self.state._probe("http://127.0.0.1:20241/ready", "https://valid-game.trycloudflare.com/"), expected)
                    self.assertEqual(opener.call_count, 2)
                    self.assertIn("health.json?check=", opener.call_args.args[0].full_url)


if __name__ == "__main__":
    unittest.main(verbosity=2)
