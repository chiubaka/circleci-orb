#! /usr/bin/env bash

# shellcheck source=/dev/null
source "$BASH_ENV"

curl https://keybase.io/codecovsecurity/pgp_keys.asc | \
gpg --no-default-keyring --keyring trustedkeys.gpg --import
# One-time step
sha_url="https://uploader.codecov.io"
sha_url="$sha_url/$VERSION/${OS}"
sha_url="$sha_url/${CODECOV_FILENAME}.SHA256SUM"

curl -Os "$sha_url"
curl -Os "$sha_url.sig"
gpgv "$CODECOV_FILENAME".SHA256SUM.sig "$CODECOV_FILENAME".SHA256SUM
shasum -a 256 -c "$CODECOV_FILENAME".SHA256SUM || \
sha256sum -c "$CODECOV_FILENAME".SHA256SUM
