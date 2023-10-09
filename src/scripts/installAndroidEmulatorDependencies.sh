#! /usr/bin/env bash
set -e

(yes || true) | sdkmanager "platform-tools" "tools"
(yes || true) | sdkmanager "platforms;$ANDROID_PLATFORM_VERSION"
(yes || true) | sdkmanager "emulator"
(yes || true) | sdkmanager "build-tools;$ANDROID_BUILD_TOOLS_VERSION"
