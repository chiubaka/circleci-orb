#! /usr/bin/env bash
set -e

export BOOT=""

echo "Waiting for AVD to finish booting"

PATH=$(dirname "$(dirname "$(command -v android)")")/platform-tools:$PATH
export PATH

until [[ "$BOOT" =~ "1" ]]; do
  sleep 5
  BOOT=$(adb -e shell getprop sys.boot_completed 2>&1)
  export BOOT
done

sleep 15

adb shell settings put global window_animation_scale 0

adb shell settings put global transition_animation_scale 0

adb shell settings put global animator_duration_scale 0

echo "Android Virtual Device is now ready."
