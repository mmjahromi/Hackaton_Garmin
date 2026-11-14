#!/bin/sh
# Build one watch app and run it in the Connect IQ simulator.
#
#   ./run-watch.sh gut-train-app          build and run the app
#   ./run-watch.sh pacepilot-app test     build and run its unit tests
#
# Used by the Run button in VS Code (.vscode/launch.json), and works from a
# terminal too. Override the SDK or key with CONNECT_IQ_SDK and
# GARMIN_DEVELOPER_KEY.
set -eu

app=${1:?"Say which app to run, for example: ./run-watch.sh gut-train-app"}
mode=${2:-run}
device=${GARMIN_DEVICE:-fenix7pro}

root=$(cd "$(dirname "$0")" && pwd)
cd "$root/$app"
[ -f monkey.jungle ] || { echo "No monkey.jungle in $app: not a watch app folder."; exit 1; }

sdk=${CONNECT_IQ_SDK:-$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")}
sdk=${sdk%/}
key=${GARMIN_DEVELOPER_KEY:-"$HOME/.garmin/developer_key.der"}
[ -f "$key" ] || { echo "Signing key not found at $key. Set GARMIN_DEVELOPER_KEY to your key's path."; exit 1; }

case "$app" in
    gut-train-app) name=guttrain ;;
    pacepilot-app) name=pacepilot ;;
    *) name=$(basename "$app") ;;
esac

mkdir -p bin
export JAVA_TOOL_OPTIONS=-Djava.awt.headless=true

if [ "$mode" = "test" ]; then
    prg="bin/$name-test.prg"
    echo "Building $app tests for $device..."
    "$sdk/bin/monkeyc" -d "$device" -f monkey.jungle -o "$prg" -y "$key" -w -l 0 -t
else
    prg="bin/$name.prg"
    echo "Building $app for $device..."
    "$sdk/bin/monkeyc" -d "$device" -f monkey.jungle -o "$prg" -y "$key" -w -l 0
fi

# The simulator sometimes stops accepting new loads after an earlier run, so
# start each run from a fresh one.
echo "Starting the simulator..."
pkill -f "bin/monkeydo" 2>/dev/null || true
pkill -f "bin/shell --transport" 2>/dev/null || true
pkill -f "ConnectIQ.app/Contents/MacOS/simulator" 2>/dev/null || true
sleep 2
unset JAVA_TOOL_OPTIONS
"$sdk/bin/connectiq"

# Wait until the simulator is listening before loading the app.
tries=0
until pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null 2>&1; do
    tries=$((tries + 1))
    [ "$tries" -gt 30 ] && { echo "The simulator did not start."; exit 1; }
    sleep 1
done
sleep 6

if [ "$mode" = "test" ]; then
    echo "Running $app tests. Results print below."
    exec "$sdk/bin/monkeydo" "$prg" "$device" -t
fi

echo "Loading $app. The watch is in the simulator window; app log lines print below. Press Ctrl+C here to detach."
exec "$sdk/bin/monkeydo" "$prg" "$device"
