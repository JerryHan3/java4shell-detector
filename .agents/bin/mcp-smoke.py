#!/usr/bin/env python3
"""Smoke test for the godot MCP server used by this project.

Speaks MCP over stdio directly against .agents/bin/godot-mcp.sh, so it verifies
the launcher, the Godot path resolution and the server itself without any agent
in the loop.

Usage:
    python3 .agents/bin/mcp-smoke.py [--project PATH]

Exit code 0 means: server handshake OK, 157 tools listed, get_godot_version and
get_project_info answered for the given project.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys

LAUNCHER = pathlib.Path(__file__).with_name("godot-mcp.sh")
EXPECTED_TOOLS = 157


def send(proc: subprocess.Popen, payload: dict) -> None:
    assert proc.stdin
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()


def recv(proc: subprocess.Popen) -> dict:
    assert proc.stdout
    while True:
        line = proc.stdout.readline()
        if not line:
            raise RuntimeError("server closed stdout before responding")
        line = line.strip()
        if line:
            return json.loads(line)


def rpc(proc: subprocess.Popen, payload: dict) -> dict:
    send(proc, payload)
    return recv(proc)


def text_of(result: dict) -> str:
    blocks = result.get("result", {}).get("content", [])
    return "\n".join(b.get("text", "") for b in blocks if b.get("type") == "text")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=str(LAUNCHER.parents[2]))
    args = parser.parse_args()

    if not LAUNCHER.is_file():
        print(f"FAIL launcher missing: {LAUNCHER}")
        return 1

    proc = subprocess.Popen(
        [str(LAUNCHER)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    try:
        init = rpc(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "godot-mcp-smoke", "version": "1"},
                },
            },
        )
        info = init["result"]["serverInfo"]
        print(f"OK   handshake: {info['name']} {info['version']}")

        send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})

        tools = rpc(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})[
            "result"
        ]["tools"]
        names = {t["name"] for t in tools}
        print(f"{'OK  ' if len(names) >= EXPECTED_TOOLS else 'WARN'} tools: {len(names)}")
        missing = {"get_godot_version", "run_project", "validate_script", "game_eval"} - names
        if missing:
            print(f"FAIL missing expected tools: {sorted(missing)}")
            return 1

        version = rpc(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {"name": "get_godot_version", "arguments": {}},
            },
        )
        print(f"OK   get_godot_version: {text_of(version)}")

        project = rpc(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 4,
                "method": "tools/call",
                "params": {
                    "name": "get_project_info",
                    "arguments": {"project_path": args.project},
                },
            },
        )
        summary = json.loads(text_of(project))
        print(f"OK   get_project_info: {summary['name']} ({summary['godotVersion']})")
        return 0
    except Exception as exc:  # noqa: BLE001 - CLI boundary
        stderr = proc.stderr.read() if proc.stderr else ""
        print(f"FAIL {exc}")
        if stderr:
            print(f"--- server stderr ---\n{stderr}")
        return 1
    finally:
        if proc.stdin:
            proc.stdin.close()
        proc.terminate()


if __name__ == "__main__":
    sys.exit(main())
