#! /usr/bin/env bash

VERSION=$1

family=$(uname -s | tr '[:upper:]' '[:lower:]')
os="windows"
[[ $family == "darwin" ]] && os="macos"

[[ $family == "linux" ]] && os="linux"
[[ $os == "linux" ]] && \
  osID=$(grep -e "^ID=" /etc/os-release | cut -c4-)
[[ $osID == "alpine" ]] && os="alpine"
echo "Detected ${os}"
echo "export OS=${os}" >> $BASH_ENV

filename="codecov"
[[ $os == "windows" ]] && filename+=".exe"
echo "export CODECOV_FILENAME=${filename}" >> $BASH_ENV

[[ $os == "macos" ]] && \
  HOMEBREW_NO_AUTO_UPDATE=1 brew install gpg

cwd=`pwd`
CODECOV_BINARY="$cwd/$filename"

echo "export CODECOV_BINARY=\"${CODECOV_BINARY}\"" >> $BASH_ENV

codecov_url="https://uploader.codecov.io"
codecov_url="$codecov_url/$VERSION"
codecov_url="$codecov_url/${os}/${filename}"

echo "Downloading from $codecov_url"

curl -Os $codecov_url

chmod +x $CODECOV_BINARY
