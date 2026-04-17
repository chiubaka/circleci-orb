#! /usr/bin/env bash
# Downloads the Codecov standalone uploader (legacy binary) used by
# uploadMonorepoCoverageResults.sh, and optionally validates it with GPG + SHA256.
# Mirrors the previous downloadCodecovUploader.sh + validateCodecovUploader.sh flow.
set -e

family=$(uname -s | tr '[:upper:]' '[:lower:]')
os="windows"
[[ $family == "darwin" ]] && os="macos"

[[ $family == "linux" ]] && os="linux"
[[ $os == "linux" ]] && \
  osID=$(grep -e "^ID=" /etc/os-release | cut -c4-)
[[ ${osID:-} == "alpine" ]] && os="alpine"
echo "Detected ${os}"
echo "export OS=${os}" >> "$BASH_ENV"

filename="codecov"
[[ $os == "windows" ]] && filename+=".exe"
echo "export CODECOV_FILENAME=${filename}" >> "$BASH_ENV"

[[ $os == "macos" ]] && \
  HOMEBREW_NO_AUTO_UPDATE=1 brew install gpg

cwd=$(pwd)
CODECOV_BINARY="$cwd/$filename"

echo "export CODECOV_BINARY=\"${CODECOV_BINARY}\"" >> "$BASH_ENV"

codecov_url="https://uploader.codecov.io"
codecov_url="$codecov_url/${VERSION:-latest}"
codecov_url="$codecov_url/${os}/${filename}"

echo "Downloading from $codecov_url"

curl -Os "$codecov_url"

chmod +x "$CODECOV_BINARY"

run_validate=${RUN_VALIDATE:-true}
if [[ "$run_validate" == "true" ]] || [[ "$run_validate" == "1" ]]; then
  # shellcheck source=/dev/null
  source "$BASH_ENV"

  curl https://keybase.io/codecovsecurity/pgp_keys.asc | \
    gpg --no-default-keyring --keyring trustedkeys.gpg --import
  sha_url="https://uploader.codecov.io"
  sha_url="$sha_url/${VERSION:-latest}/${OS}"
  sha_url="$sha_url/${CODECOV_FILENAME}.SHA256SUM"

  curl -Os "$sha_url"
  curl -Os "$sha_url.sig"
  gpgv "$CODECOV_FILENAME".SHA256SUM.sig "$CODECOV_FILENAME".SHA256SUM
  shasum -a 256 -c "$CODECOV_FILENAME".SHA256SUM || \
    sha256sum -c "$CODECOV_FILENAME".SHA256SUM
fi
