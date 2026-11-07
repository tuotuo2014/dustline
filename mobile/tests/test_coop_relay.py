"""Real TCP/WebSocket regression checks for the mobile multiplayer relay."""
from functools import partial
from pathlib import Path
import json
import socket
import struct
import sys
import threading
import time
import unittest

MOBILE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MOBILE))
from serve_mobile import MobileHandler, MobileHTTPServer
from coop_relay import MAX_PACKET
from wsproto import WSConnection, ConnectionType
from wsproto.events import Request, AcceptConnection, BytesMessage, TextMessage, CloseConnection, Ping


class QuietHandler(MobileHandler):
    def log_message(self, *_args):
        pass


class Player:
    def __init__(self, port):
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=3)
        self.ws = WSConnection(ConnectionType.CLIENT)
        self.inbox = []
        self.parts = bytearray()
        self.sock.sendall(self.ws.send(Request(host=f"localhost:{port}", target="/multiplayer")))
        self.expect_type(AcceptConnection)

    def send(self, value):
        self.sock.sendall(self.ws.send(TextMessage(data=json.dumps(value))))

    def packet(self, target, payload=b"game-state", mode=2, channel=0):
        self.sock.sendall(self.ws.send(BytesMessage(data=struct.pack("<iBB", target, mode, channel) + payload)))

    def read(self):
        data = self.sock.recv(65536)
        if not data:
            raise EOFError("Relay closed socket")
        self.ws.receive_data(data)
        for event in self.ws.events():
            if isinstance(event, Ping):
                self.sock.sendall(self.ws.send(event.response()))
            elif isinstance(event, (BytesMessage, TextMessage)):
                self.parts.extend(event.data.encode() if isinstance(event.data, str) else event.data)
                if event.message_finished:
                    self.inbox.append(json.loads(self.parts) if isinstance(event, TextMessage) else bytes(self.parts))
                    self.parts.clear()
            else:
                self.inbox.append(event)

    def expect_type(self, cls):
        while True:
            for i, event in enumerate(self.inbox):
                if isinstance(event, cls):
                    return self.inbox.pop(i)
            self.read()

    def control(self, op):
        while True:
            for i, event in enumerate(self.inbox):
                if isinstance(event, dict) and event.get("op") == op:
                    return self.inbox.pop(i)
            self.read()

    def next_packet(self):
        return self.expect_type(bytes)

    def close(self):
        try:
            self.sock.sendall(self.ws.send(CloseConnection(code=1000)))
        except Exception:
            pass
        self.sock.close()


class RelayTests(unittest.TestCase):
    def setUp(self):
        self.server = MobileHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(MOBILE / "builds/web")))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.players = []

    def tearDown(self):
        for peer in self.players:
            peer.close()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def player(self):
        peer = Player(self.server.server_port)
        self.players.append(peer)
        return peer

    def host(self):
        peer = self.player()
        peer.send({"op": "host", "protocol": 1})
        welcome = peer.control("welcome")
        self.assertEqual(welcome["id"], 1)
        self.assertEqual(welcome["peers"], [])
        return peer, welcome["code"]

    def join(self, code):
        peer = self.player()
        peer.send({"op": "join", "protocol": 1, "code": code})
        welcome = peer.control("welcome")
        return peer, welcome

    def wait_for(self, condition):
        deadline = time.monotonic() + 2
        while not condition() and time.monotonic() < deadline:
            time.sleep(.01)
        self.assertTrue(condition())

    def test_real_join_route_sender_and_broadcast(self):
        host, code = self.host()
        a, wa = self.join(code)
        b, wb = self.join(code)
        self.assertEqual(wa["peers"], [1])
        self.assertEqual(wb["peers"], [1, wa["id"]])
        self.assertEqual(host.control("peer_joined")["id"], wa["id"])
        self.assertEqual(host.control("peer_joined")["id"], wb["id"])
        self.assertEqual(a.control("peer_joined")["id"], wb["id"])
        a.packet(1, b"actual-client", 1, 2)
        self.assertEqual(host.next_packet(), struct.pack("<iBB", wa["id"], 1, 2) + b"actual-client")
        host.packet(0, b"world")
        for peer in (a, b):
            self.assertEqual(peer.next_packet(), struct.pack("<iBB", 1, 2, 0) + b"world")
        host.packet(-wa["id"], b"exclude-one")
        self.assertTrue(b.next_packet().endswith(b"exclude-one"))
        host.packet(wa["id"], b"only-a")
        self.assertTrue(a.next_packet().endswith(b"only-a"))

    def test_clients_cannot_send_as_another_peer_or_control_room(self):
        host, code = self.host()
        bad, welcome = self.join(code)
        bad.packet(0, b"forged-broadcast")
        self.assertIn("只能向房主", bad.control("error")["message"])
        self.assertEqual(host.control("peer_left")["id"], welcome["id"])
        bad2, _ = self.join(code)
        bad2.send({"op": "kick", "id": 1})
        self.assertIn("只有房主", bad2.control("error")["message"])
        self.assertFalse(self.server.relay_hub.rooms[code].locked)

    def test_capacity_lock_and_missing_room(self):
        host, code = self.host()
        members = [self.join(code)[0] for _ in range(3)]
        fifth = self.player()
        fifth.send({"op": "join", "protocol": 1, "code": code})
        self.assertIn("已满", fifth.control("error")["message"])
        members[-1].close()
        host.control("peer_left")
        host.send({"op": "lock", "locked": True})
        self.wait_for(lambda: self.server.relay_hub.rooms[code].locked)
        locked = self.player()
        locked.send({"op": "join", "protocol": 1, "code": code})
        self.assertIn("已出发", locked.control("error")["message"])
        host.send({"op": "lock", "locked": False})
        self.wait_for(lambda: not self.server.relay_hub.rooms[code].locked)
        replacement, welcome = self.join(code)
        self.assertEqual(welcome["id"], 5)
        missing = self.player()
        missing.send({"op": "join", "protocol": 1, "code": "ZZZZZZ"})
        self.assertIn("没有找到", missing.control("error")["message"])

    def test_room_isolation_and_host_disconnect(self):
        h1, code1 = self.host()
        h2, code2 = self.host()
        a, _ = self.join(code1)
        b, _ = self.join(code2)
        h1.packet(0, b"first-room")
        h2.packet(0, b"second-room")
        self.assertTrue(a.next_packet().endswith(b"first-room"))
        self.assertTrue(b.next_packet().endswith(b"second-room"))
        h1.close()
        self.assertIn("房主已离开", a.control("closed")["message"])
        self.wait_for(lambda: code1 not in self.server.relay_hub.rooms)
        h2.packet(0, b"still-connected")
        self.assertTrue(b.next_packet().endswith(b"still-connected"))

    def test_host_kick_and_return_unique_identity(self):
        host, code = self.host()
        a, welcome = self.join(code)
        host.send({"op": "kick", "id": welcome["id"]})
        self.assertIn("已离开", a.control("error")["message"])
        self.assertEqual(host.control("peer_left")["id"], welcome["id"])
        replacement, new_welcome = self.join(code)
        self.assertNotEqual(welcome["id"], new_welcome["id"])

    def test_malformed_packet_version_and_size(self):
        host, code = self.host()
        for payload in [b"tiny", struct.pack("<iBB", 1, 8, 0) + b"x", struct.pack("<iBB", 1, 2, 3) + b"x", struct.pack("<iBB", 1, 2, 0) + b"x" * (MAX_PACKET + 1)]:
            peer, _ = self.join(code)
            peer.sock.sendall(peer.ws.send(BytesMessage(data=payload)))
            self.assertEqual(peer.control("error")["op"], "error")
            host.control("peer_left")
        bad = self.player()
        bad.send({"op": "host", "protocol": 99})
        self.assertIn("版本", bad.control("error")["message"])
        bad_json = self.player()
        bad_json.sock.sendall(bad_json.ws.send(TextMessage(data="[]")))
        self.assertEqual(bad_json.control("error")["op"], "error")

    def test_ping_and_fragmented_binary_packets(self):
        host, code = self.host()
        peer, welcome = self.join(code)
        peer.sock.sendall(peer.ws.send(Ping(payload=b"is-alive")))
        from wsproto.events import Pong
        self.assertEqual(peer.expect_type(Pong).payload, b"is-alive")
        frame = struct.pack("<iBB", 1, 0, 1) + b"fragmented-real-data"
        peer.sock.sendall(peer.ws.send(BytesMessage(data=frame[:8], message_finished=False)))
        peer.sock.sendall(peer.ws.send(BytesMessage(data=frame[8:], message_finished=True)))
        self.assertEqual(host.next_packet(), struct.pack("<iBB", welcome["id"], 0, 1) + b"fragmented-real-data")


if __name__ == "__main__":
    unittest.main(verbosity=2)
