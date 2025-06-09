#! /usr/bin/env bash
set -e

{
  echo "export PATH=\"$PATH:/usr/local/opt/node@$NODE_VERSION/bin:~/.yarn/bin:~/project/node_modules/.bin:~/project/example/node_modules/.bin\""
  echo "export ANDROID_HOME=\"/usr/local/share/android-commandlinetools\""
  echo "export ANDROID_SDK_ROOT=\"/usr/local/share/android-commandlinetools\""
  echo "export PATH=\"$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH\""
  echo "export QEMU_AUDIO_DRV=none"
  echo "export JAVA_HOME=$(/usr/libexec/java_home)"
} >> "$BASH_ENV"

# shellcheck disable=1090
source "$BASH_ENV"
