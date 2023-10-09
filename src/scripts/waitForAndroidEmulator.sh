#! /usr/bin/env bash
set -xe

echo "Waiting for AVD to finish booting"

adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done; input keyevent 82'

sleep 15

adb shell settings put global window_animation_scale 0

adb shell settings put global transition_animation_scale 0

adb shell settings put global animator_duration_scale 0

echo "Android Virtual Device is now ready."
