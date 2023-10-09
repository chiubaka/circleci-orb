#! /usr/bin/env bash
set -e

yes | sdkmanager "platform-tools" "tools" > /dev/null
yes | sdkmanager "platforms;$ANDROID_PLATFORM_VERSION" > /dev/null
yes | sdkmanager "emulator" > /dev/null
yes | sdkmanager "build-tools;$ANDROID_BUILD_TOOLS_VERSION" > /dev/null
yes | sdkmanager --licenses > /dev/null
