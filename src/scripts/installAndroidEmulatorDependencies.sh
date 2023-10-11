#! /usr/bin/env bash
set -e

(yes || true) | sdkmanager "platform-tools" "tools" > /dev/null
(yes || true) | sdkmanager "platforms;$ANDROID_PLATFORM_VERSION" > /dev/null
(yes || true) | sdkmanager "emulator" > /dev/null
(yes || true) | sdkmanager "build-tools;$ANDROID_BUILD_TOOLS_VERSION" > /dev/null
