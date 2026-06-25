#!/usr/bin/env python3
import json
import os
import queue
import socket
import struct
import sys
import threading

SOCKET_PATH = os.path.expanduser("~/.cache/firefox-bridge/socket")
RESPONSE_TYPES = {"urlResponse", "tabsResponse"}
QUERY_TYPES = {"getUrl", "getTabs"}

response_queue = queue.Queue()
request_lock = threading.Lock()


def send_to_browser(msg):
    data = json.dumps(msg).encode()
    sys.stdout.buffer.write(struct.pack("<I", len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


def read_from_browser():
    raw = sys.stdin.buffer.read(4)
    if len(raw) < 4:
        return None
    length = struct.unpack("<I", raw)[0]
    return json.loads(sys.stdin.buffer.read(length))


def handle_socket_connection(conn):
    try:
        chunks = []
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
        msg = json.loads(b"".join(chunks))

        if msg.get("type") in QUERY_TYPES:
            with request_lock:
                send_to_browser(msg)
                try:
                    response = response_queue.get(timeout=5)
                    conn.sendall(json.dumps(response).encode())
                except queue.Empty:
                    conn.sendall(json.dumps({"error": "timeout"}).encode())
        else:
            send_to_browser(msg)
    except Exception as e:
        print(f"socket error: {e}", file=sys.stderr)
    finally:
        conn.close()


def socket_server():
    os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
    if os.path.exists(SOCKET_PATH):
        os.remove(SOCKET_PATH)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCKET_PATH)
    os.chmod(SOCKET_PATH, 0o600)
    srv.listen(5)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle_socket_connection, args=(conn,), daemon=True).start()


threading.Thread(target=socket_server, daemon=True).start()

while True:
    msg = read_from_browser()
    if msg is None:
        break
    if msg.get("type") in RESPONSE_TYPES:
        response_queue.put(msg)
