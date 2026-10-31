#!/usr/bin/env bash
# Runs the test suite with coverage and fails when RouterCore's line coverage is below the
# threshold (default 90%).
set -euo pipefail

cd "$(dirname "$0")/.."
threshold="${1:-90}"

swift test --enable-code-coverage
report="$(swift test --show-codecov-path)"

python3 - "$report" "$threshold" "$PWD/Sources/RouterCore/" <<'PY'
import json
import sys

report, threshold, prefix = sys.argv[1], float(sys.argv[2]), sys.argv[3]
files = {}
for export in json.load(open(report))["data"]:
    for entry in export["files"]:
        if entry["filename"].startswith(prefix):
            lines = entry["summary"]["lines"]
            previous = files.get(entry["filename"])
            if previous is None or lines["covered"] > previous["covered"]:
                files[entry["filename"]] = lines

if not files:
    sys.exit("error: no RouterCore files in the coverage report")

for name, lines in sorted(files.items()):
    print(f"{lines['percent']:6.1f}%  {lines['covered']:4}/{lines['count']:<4}  {name[len(prefix):]}")

count = sum(lines["count"] for lines in files.values())
covered = sum(lines["covered"] for lines in files.values())
coverage = 100 * covered / count
print(f"RouterCore line coverage {coverage:.1f}% (threshold {threshold:g}%)")
if coverage < threshold:
    sys.exit(f"error: RouterCore line coverage {coverage:.1f}% is below {threshold:g}%")
PY
