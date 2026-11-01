#!/usr/bin/env bash
# Fails if RouterCore's public interface references SwiftUI, so the module stays usable from
# macOS command-line tools and UI-free packages.
set -euo pipefail

cd "$(dirname "$0")/.."
build_path="$(mktemp -d)"
trap 'rm -rf "$build_path"' EXIT

swift build --product RouterCore --build-path "$build_path" \
	-Xswiftc -enable-library-evolution \
	-Xswiftc -emit-module-interface

interface="$(find "$build_path" -name 'RouterCore.swiftinterface' -not -name '*.private.*' | head -n 1)"
if [[ -z "$interface" ]]; then
	echo "error: RouterCore.swiftinterface was not emitted" >&2
	exit 1
fi

if grep -n 'SwiftUI' "$interface"; then
	echo "error: RouterCore's interface references SwiftUI ($interface)" >&2
	exit 1
fi

if grep -rn --include='*.swift' -E '^\s*(@_exported\s+)?import\s+SwiftUI' Sources/RouterCore; then
	echo "error: a RouterCore source file imports SwiftUI" >&2
	exit 1
fi

echo "RouterCore is SwiftUI-free ($interface)"
