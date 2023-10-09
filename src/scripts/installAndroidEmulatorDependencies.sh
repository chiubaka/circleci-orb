#! /usr/bin/env bash
set -e

yes | sdkmanager "platform-tools" "tools"
yes | sdkmanager "platforms;$ANDROID_PLATFORM_VERSION"
yes | sdkmanager "emulator"
yes | sdkmanager "build-tools;$ANDROID_BUILD_TOOLS_VERSION"
yes | sdkmanager --licenses
