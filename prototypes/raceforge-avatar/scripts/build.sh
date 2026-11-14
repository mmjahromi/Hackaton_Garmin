#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
key_path="${1:?Usage: scripts/build.sh /path/to/developer_key [--test]}"
version="$("$sdk_dir/bin/monkeyc" -v)"
if [[ "$version" != 'Connect IQ Compiler version: 9.1.0' ]]; then
    echo "Expected SDK 9.1.0; found: $version" >&2
    exit 1
fi
mkdir -p bin
if [[ "${2:-}" == '--test' ]]; then
    "$sdk_dir/bin/monkeyc" -f monkey.jungle -d fenix7pro_sim \
        -o bin/RaceForge-tests.prg -y "$key_path" -w -l 0 -t 2>&1 | tee bin/test-build.log
else
    "$sdk_dir/bin/monkeyc" -f monkey.jungle -d fenix7pro_sim \
        -o bin/RaceForge.prg -y "$key_path" -w -l 0 2>&1 | tee bin/build.log
fi
