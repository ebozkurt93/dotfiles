#!/usr/bin/env python3
"""Send a command to the Firefox bridge socket. Reads JSON from a file path
passed as the first argument. Prints the response to stdout for query commands."""
import json
import os
import socket
import sys

SOCKET_PATH = os.path.expanduser("~/.cache/firefox-bridge/socket")
QUERY_TYPES = {"getUrl", "getTabs"}

with open(sys.argv[1]) as f:
    cmd = json.load(f)

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCKET_PATH)
s.sendall(json.dumps(cmd).encode())
s.shutdown(socket.SHUT_WR)

if cmd.get("type") in QUERY_TYPES:
    data = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        data += chunk
    sys.stdout.write(data.decode())

s.close()
