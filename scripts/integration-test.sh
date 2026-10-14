#!/bin/bash
# Pairs the built app with scripts/mock_tv.py and sends commands, checking both sides.
# Run after scripts/build.sh. Needs python3 and openssl; no TV.
set -euo pipefail
cd "$(dirname "$0")/.."
APP_BIN="dist/PhilipsTV Menubar.app/Contents/MacOS/PhilipsTVMenubar"
WORK="$(mktemp -d /tmp/philipstv-test.XXXXXX)"
export PHILIPSTV_DATA_DIR="$WORK/data"

"$APP_BIN" --self-check
"$APP_BIN" --export-client-cert "$WORK/client.pem"

python3 scripts/mock_tv.py --client-cert "$WORK/client.pem" --code-file "$WORK/code.txt" \
  --log "$WORK/events.jsonl" --port 16466 --pair-port 16467 > "$WORK/mock.out" 2>&1 &
MOCK_PID=$!
trap 'kill $MOCK_PID 2>/dev/null || true; cat "$WORK/mock.out"' EXIT
for _ in $(seq 50); do grep -q listening "$WORK/mock.out" 2>/dev/null && break; sleep 0.2; done

"$APP_BIN" --pair --host 127.0.0.1 --pair-port 16467 --code-file "$WORK/code.txt"
"$APP_BIN" --host 127.0.0.1 --port 16466 --send-key HOME,VOLUME_UP,TV_INPUT_HDMI_2 \
  --launch com.netflix.ninja --text hello | tee "$WORK/cli.out"

fail=0
expect() { if grep -q -- "$2" "$1"; then echo "ok   $2"; else echo "MISSING $2 in $1"; fail=1; fi; }
expect "$WORK/events.jsonl" '"event": "paired"'
expect "$WORK/events.jsonl" '"event": "configured", "features": 615'
expect "$WORK/events.jsonl" '"name": "HOME", "direction": 3'
expect "$WORK/events.jsonl" '"name": "VOLUME_UP"'
expect "$WORK/events.jsonl" '"name": "TV_INPUT_HDMI_2"'
expect "$WORK/events.jsonl" 'market://launch?id=com.netflix.ninja'
expect "$WORK/events.jsonl" '"text": "hello"'
expect "$WORK/cli.out" 'DEVICE vendor=Philips model=MockTV'
expect "$WORK/cli.out" 'POWER on'
expect "$WORK/cli.out" 'VOLUME 13/100'
expect "$WORK/cli.out" 'APP com.netflix.ninja'
exit $fail
