#!/usr/bin/env python3
"""A minimal LSP server for tests.

Records what the client sends (initializationOptions, workspace/configuration
answers, didChangeConfiguration settings) as JSON lines in $FAKE_LS_LOG.
"""
import json
import os
import sys

LOG = os.environ["FAKE_LS_LOG"]
stdin, stdout = sys.stdin.buffer, sys.stdout.buffer


def log(kind, value):
    with open(LOG, "a") as f:
        f.write(json.dumps({"kind": kind, "value": value}) + "\n")


def read():
    length = None
    while True:
        line = stdin.readline()
        if not line:
            return None
        line = line.strip()
        if not line:
            break
        name, _, value = line.partition(b":")
        if name.lower() == b"content-length":
            length = int(value)
    return json.loads(stdin.read(length))


def send(msg):
    body = json.dumps({"jsonrpc": "2.0", **msg}).encode()
    stdout.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    stdout.flush()


while (msg := read()) is not None:
    method = msg.get("method")
    if method == "initialize":
        log("initializationOptions", msg["params"].get("initializationOptions"))
        send({"id": msg["id"], "result": {"capabilities": {}}})
    elif method == "initialized":
        send({"id": 1000, "method": "workspace/configuration",
              "params": {"items": [{"section": "fake"}]}})
    elif method is None and msg.get("id") == 1000:
        log("workspace/configuration", msg.get("result"))
    elif method == "workspace/didChangeConfiguration":
        log("didChangeConfiguration", msg["params"].get("settings"))
    elif method == "shutdown":
        send({"id": msg["id"], "result": None})
    elif method == "exit":
        break
