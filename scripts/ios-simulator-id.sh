#!/usr/bin/env bash
# Prints the identifier of an available iPhone simulator on the newest installed iOS runtime.
set -euo pipefail

xcrun simctl list devices available --json | python3 -c '
import json
import sys

devices = json.load(sys.stdin)["devices"]
runtimes = sorted(
    (runtime for runtime in devices if ".SimRuntime.iOS-" in runtime),
    key=lambda runtime: [int(part) for part in runtime.rsplit("iOS-", 1)[1].split("-")],
    reverse=True,
)
for runtime in runtimes:
    for device in devices[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("error: no available iPhone simulator")
'
