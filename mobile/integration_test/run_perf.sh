#!/usr/bin/env bash
# Runs integration_test/perf_test.dart in profile mode and writes the
# timeline summaries to build/perf/. Usage, from mobile/:
#
#   integration_test/run_perf.sh [device-id]
#
# A fresh install asks for location permission before Home can load its
# prayer times, and a test can't answer that system prompt. The permission
# is granted over adb as soon as `flutter drive` has installed the app.
set -euo pipefail

device="${1:-}"
adb_cmd=(adb)
drive_device=()
if [[ -n "$device" ]]; then
  adb_cmd=(adb -s "$device")
  drive_device=(-d "$device")
fi

(
  for _ in $(seq 1 600); do
    if "${adb_cmd[@]}" shell pm list packages 2>/dev/null | grep -q '^package:com.lahuma.app$'; then
      "${adb_cmd[@]}" shell pm grant com.lahuma.app android.permission.ACCESS_COARSE_LOCATION
      exit 0
    fi
    sleep 0.5
  done
) &
granter=$!

status=0
flutter drive --profile --no-dds "${drive_device[@]}" \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_test.dart || status=$?
kill "$granter" 2>/dev/null || true
exit $status
