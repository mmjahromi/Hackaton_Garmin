#!/bin/sh
set -eu
cd "$(dirname "$0")"
sdk_path=${CONNECT_IQ_SDK:-$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")}
key_path=${GARMIN_DEVELOPER_KEY:-"$HOME/.garmin/developer_key.der"}
mkdir -p bin
export JAVA_TOOL_OPTIONS=-Djava.awt.headless=true
"$sdk_path/bin/monkeyc" -d fenix7pro -f monkey.jungle -o bin/pacepilot.prg -y "$key_path" -w -l 0
"$sdk_path/bin/monkeyc" -d fenix7pro -f monkey.jungle -o bin/pacepilot-test.prg -y "$key_path" -w -l 0 -t
