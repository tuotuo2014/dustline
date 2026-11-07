"""Small, room-isolated WebSocket relay for actual Godot player connections.

The relay assigns identities and forwards opaque Godot RPC packets; it never
creates players, simulates gameplay, or interprets serialized Godot objects.
"""
from collections import deque
import json
from pathlib import Path
import secrets
import select
import socket
import struct
import sys
import threading
import time

# Keep pinned, pure-Python packages local to this independent mobile edition.
_VENDOR = str(Path(__file__).resolve().parent / "tools" / "python")
if _VENDOR not in sys.path:
    sys.path.insert(0, _VENDOR)
from wsproto import ConnectionType, WSConnection
from wsproto.events import AcceptConnection, BytesMessage, CloseConnection, Ping, Pong, Request, TextMessage
from wsproto.utilities import LocalProtocolError, RemoteProtocolError

PROTOCOL = 1
PATH = "/multiplayer"
MAX_PLAYERS = 4
MAX_ROOMS = 32
MAX_CONNECTIONS = 160
MAX_PACKET = 256 * 1024
MAX_QUEUE_BYTES = 4 * 1024 * 1024
MAX_QUEUE_MESSAGES = 512
HEADER = struct.Struct("<iBB")
_HUB_LOCK = threading.Lock()


class Room:
    def __init__(self, code, host):
        self.code = code
        self.members = {1: host}
        self.locked = False
        self.next_id = 2


class RelayHub:
    def __init__(self):
        self.lock = threading.RLock()
        self.rooms = {}
        self.connections = set()
        self.stopped = False

    def register(self, peer):
        with self.lock:
            if self.stopped or len(self.connections) >= MAX_CONNECTIONS:
                return False
            self.connections.add(peer)
            return True

    def command(self, peer, value):
        with self.lock:
            op = value.get("op") if isinstance(value, dict) else None
            if peer.room is None:
                if op not in ("host", "join") or value.get("protocol") != PROTOCOL:
                    return peer.fail("联机版本不一致，请刷新游戏后重试。")
                if op == "host":
                    if len(self.rooms) >= MAX_ROOMS:
                        return peer.fail("房间暂时已满，请稍后重试。")
                    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
                    while True:
                        code = "".join(secrets.choice(alphabet) for _ in range(6))
                        if code not in self.rooms:
                            break
                    room = Room(code, peer)
                    self.rooms[code] = room
                    peer.identity, peer.room = 1, room
                    peer.control(op="welcome", id=1, code=code, peers=[])
                    return
                code = value.get("code", "")
                room = self.rooms.get(code.strip().upper()) if isinstance(code, str) else None
                if room is None:
                    return peer.fail("没有找到这个房间，请检查六位房间码。")
                if room.locked:
                    return peer.fail("该小队已出发，请等待本次行动结束。")
                if len(room.members) >= MAX_PLAYERS:
                    return peer.fail("房间已满，最多四位真人玩家。")
                existing = list(room.members)
                peer.identity, peer.room = room.next_id, room
                room.next_id += 1
                # Welcome must be queued before any peer event or game packet.
                peer.control(op="welcome", id=peer.identity, code=room.code, peers=existing)
                for member in room.members.values():
                    member.control(op="peer_joined", id=peer.identity)
                room.members[peer.identity] = peer
                return
            if peer.identity != 1:
                return peer.fail("只有房主可以管理房间。")
            if op == "lock" and isinstance(value.get("locked"), bool):
                peer.room.locked = value["locked"]
            elif op == "kick" and type(value.get("id")) is int and value["id"] != 1:
                target = peer.room.members.get(value["id"])
                if target:
                    target.fail("你已离开该房间。")
            else:
                peer.fail("无法识别的联机请求。")

    def packet(self, peer, packet):
        if len(packet) <= HEADER.size or len(packet) > MAX_PACKET + HEADER.size:
            return peer.fail("联机数据大小无效。")
        target, mode, channel = HEADER.unpack_from(packet)
        if mode not in (0, 1, 2) or channel not in (0, 1, 2):
            return peer.fail("联机数据通道无效。")
        with self.lock:
            room = peer.room
            if room is None or room.members.get(peer.identity) is not peer:
                return peer.fail("请先创建或加入房间。")
            if peer.identity != 1:
                if target != 1:
                    return peer.fail("客户端只能向房主发送游戏数据。")
                recipients = [room.members.get(1)]
            elif target > 0:
                recipients = [room.members.get(target)]
            else:
                recipients = [member for identity, member in room.members.items()
                              if identity != 1 and identity != -target]
            # The authenticated socket identity replaces the supplied destination.
            outgoing = HEADER.pack(peer.identity, mode, channel) + packet[HEADER.size:]
            for recipient in recipients:
                if recipient is not None and recipient is not peer:
                    recipient.enqueue("binary", outgoing)

    def disconnect(self, peer):
        with self.lock:
            self.connections.discard(peer)
            room = peer.room
            if room is None or room.members.get(peer.identity) is not peer:
                return
            peer.room = None
            room.members.pop(peer.identity, None)
            if peer.identity == 1:
                self.rooms.pop(room.code, None)
                for member in list(room.members.values()):
                    member.room = None
                    member.fail("房主已离开，房间已关闭。", op="closed", code=1001)
                room.members.clear()
            else:
                for member in room.members.values():
                    member.control(op="peer_left", id=peer.identity)

    def close(self):
        with self.lock:
            self.stopped = True
            for peer in list(self.connections):
                peer.fail("联机服务已关闭，请重新打开最新入口。", op="closed", code=1001)


def get_hub(server):
    with _HUB_LOCK:
        if not hasattr(server, "relay_hub"):
            server.relay_hub = RelayHub()
        return server.relay_hub


class RelayConnection:
    def __init__(self, sock, hub, ws):
        self.socket, self.hub, self.ws = sock, hub, ws
        self.identity, self.room = 0, None
        self.queue = deque()
        self.queue_lock = threading.Lock()
        self.queue_bytes = 0
        self.closing = False
        self.close_received = False
        self.created = self.last_received = self.last_ping = self.rate_at = time.monotonic()
        self.byte_tokens = 8 * 1024 * 1024
        self.message_tokens = 1200.0
        self.parts = bytearray()
        self.message_kind = None

    def control(self, **value):
        self.enqueue("text", json.dumps(value, ensure_ascii=False, separators=(",", ":")))

    def enqueue(self, kind, payload):
        with self.queue_lock:
            if self.closing:
                return
            size = len(payload.encode()) if isinstance(payload, str) else len(payload)
            if len(self.queue) >= MAX_QUEUE_MESSAGES or self.queue_bytes + size > MAX_QUEUE_BYTES:
                self._fail_locked("连接过慢，请重新加入房间。", "error", 1013)
                return
            self.queue.append((kind, payload))
            self.queue_bytes += size

    def _fail_locked(self, message, op, code):
        self.closing = True
        self.queue.clear()
        self.queue_bytes = 0
        self.queue.append(("text", json.dumps({"op": op, "message": message}, ensure_ascii=False)))
        self.queue.append(("close", (code, message.encode("utf-8")[:123].decode("utf-8", "ignore"))))

    def fail(self, message, op="error", code=1008):
        with self.queue_lock:
            if not self.closing:
                self._fail_locked(message, op, code)

    def drain(self):
        with self.queue_lock:
            items = list(self.queue)
            self.queue.clear()
            self.queue_bytes = 0
        return items

    def receive(self, event):
        now = time.monotonic()
        self.last_received = now
        if isinstance(event, Ping):
            self.enqueue("pong", event.payload)
            return
        if isinstance(event, Pong):
            return
        if isinstance(event, CloseConnection):
            self.close_received = True
            if self.closing:
                return
            with self.queue_lock:
                self.closing = True
                self.queue.clear()
                self.queue_bytes = 0
                self.queue.append(("close", (event.code if event.code != 1006 else 1000, "")))
            return
        if not isinstance(event, (BytesMessage, TextMessage)) or self.closing:
            return
        fragment = event.data.encode() if isinstance(event.data, str) else event.data
        kind = "text" if isinstance(event, TextMessage) else "binary"
        if self.message_kind is not None and kind != self.message_kind:
            return self.fail("无效的联机消息。")
        self.message_kind = kind
        elapsed = now - self.rate_at
        self.rate_at = now
        self.byte_tokens = min(8 * 1024 * 1024, self.byte_tokens + elapsed * 4 * 1024 * 1024) - len(fragment)
        self.message_tokens = min(1200, self.message_tokens + elapsed * 600)
        maximum = 4096 if kind == "text" else MAX_PACKET + HEADER.size
        if self.byte_tokens < 0 or len(self.parts) + len(fragment) > maximum:
            return self.fail("联机数据超出限制。", code=1009)
        self.parts.extend(fragment)
        if not event.message_finished:
            return
        self.message_tokens -= 1
        if self.message_tokens < 0:
            return self.fail("联机请求过于频繁。")
        message = bytes(self.parts)
        self.parts.clear()
        self.message_kind = None
        if kind == "binary":
            self.hub.packet(self, message)
        else:
            try:
                self.hub.command(self, json.loads(message))
            except (ValueError, TypeError, UnicodeDecodeError, RecursionError):
                self.fail("无效的联机消息。")

    def run(self):
        pending = bytearray()
        closing_at = None
        sock = self.socket
        sock.setblocking(False)
        try:
            while True:
                now = time.monotonic()
                if self.room is None and not self.identity and now - self.created > 15:
                    self.fail("加入房间超时，请重新连接。")
                if now - self.last_received > 180:
                    self.fail("联机连接已超时，请重新加入。", code=1001)
                if not self.closing and now - self.last_ping > 20:
                    self.last_ping = now
                    self.enqueue("ping", b"wasteland")
                # Bound both the event queue and bytes already encoded for a slow peer.
                if len(pending) < 64 * 1024:
                    for kind, payload in self.drain():
                        if kind == "text": event = TextMessage(data=payload)
                        elif kind == "binary": event = BytesMessage(data=payload)
                        elif kind == "ping": event = Ping(payload=payload)
                        elif kind == "pong": event = Pong(payload=payload)
                        else: event = CloseConnection(code=payload[0], reason=payload[1])
                        pending.extend(self.ws.send(event))
                if self.closing:
                    if closing_at is None:
                        closing_at = now
                    if (not pending and self.close_received) or now - closing_at > 2:
                        break
                readable, writable, _ = select.select([sock], [sock] if pending else [], [], .05)
                if writable:
                    try:
                        sent = sock.send(memoryview(pending)[:65536])
                        del pending[:sent]
                    except BlockingIOError:
                        pass
                if readable:
                    try:
                        data = sock.recv(65536)
                    except BlockingIOError:
                        continue
                    if not data:
                        break
                    self.ws.receive_data(data)
                    for event in self.ws.events():
                        self.receive(event)
        except (OSError, ValueError, LocalProtocolError, RemoteProtocolError):
            pass
        finally:
            self.hub.disconnect(self)
            sock.setblocking(True)


def handle_upgrade(handler):
    """Called after HTTP headers are parsed, with an unbuffered request reader."""
    if handler.headers.get("Upgrade", "").lower() != "websocket":
        handler.send_error(426, "WebSocket connection required")
        return
    ws = WSConnection(ConnectionType.SERVER)
    try:
        headers = [(key.encode("ascii"), value.encode("latin1")) for key, value in handler.headers.items()]
        ws.initiate_upgrade_connection(headers, handler.path)
        if not any(isinstance(event, Request) for event in ws.events()):
            handler.send_error(400, "Invalid WebSocket handshake")
            return
        hub = get_hub(handler.server)
        peer = RelayConnection(handler.connection, hub, ws)
        if not hub.register(peer):
            handler.send_error(503, "Multiplayer service is full")
            return
        handler.close_connection = True
        try:
            handler.wfile.write(ws.send(AcceptConnection()))
            handler.wfile.flush()
            peer.run()
        finally:
            hub.disconnect(peer)
    except (OSError, ValueError, UnicodeError, LocalProtocolError, RemoteProtocolError):
        handler.close_connection = True
