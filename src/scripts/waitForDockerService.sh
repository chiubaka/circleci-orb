#! /usr/bin/env bash
set -e

DOCKERIZE_BINARY=${DOCKERIZE_BINARY:-dockerize}

$DOCKERIZE_BINARY \
  -wait "$URL" \
  -wait-retry-interval "$RETRY_INTERVAL" \
  -timeout "$TIMEOUT"
