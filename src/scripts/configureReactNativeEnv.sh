#! /usr/bin/env bash
set -e

echo 'export PATH="$PATH:/usr/local/opt/node@$NODE_VERSION/bin:~/.yarn/bin:~/project/node_modules/.bin:~/project/example/node_modules/.bin"' >> $BASH_ENV
echo 'export ANDROID_HOME="/usr/local/share/android-commandlinetools"' >> $BASH_ENV
echo 'export ANDROID_SDK_ROOT="/usr/local/share/android-commandlinetools"' >> $BASH_ENV
echo 'export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH"' >> $BASH_ENV
echo 'export QEMU_AUDIO_DRV=none' >> $BASH_ENV
echo 'export JAVA_HOME=$(/usr/libexec/java_home)' >> $BASH_ENV

source $BASH_ENV
