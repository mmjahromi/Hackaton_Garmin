#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh "${1:?Usage: bash scripts/test.sh /path/to/developer_key}" --test
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
"$sdk_dir/bin/connectiq"
set +e
"$sdk_dir/bin/monkeydo" bin/RaceForge-tests.prg fenix7pro -t 2>&1 | tee bin/m2-tests.log
runner_status=${PIPESTATUS[0]}
set -e
if rg -q '^PASSED \(passed=[1-9][0-9]*, failed=0, errors=0\)' bin/m2-tests.log; then
    echo "Simulator suite passed (SDK runner exit $runner_status; test summary checked)."
else
    echo "Simulator suite did not pass; inspect bin/m2-tests.log." >&2
    exit 1
fi
