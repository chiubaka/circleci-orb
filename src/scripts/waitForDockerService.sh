#! /usr/bin/env bash
set -e

DOCKER_BINARY=${DOCKER_BINARY:-docker}

NETWORK_NAME=$($DOCKER_BINARY container inspect "$CONTAINER_NAME" --format \'\{\{range \$net,\$v := .NetworkSettings.Networks\}\}\{\{printf "%s\n" \$net\}\}\{\{end\}\}\')

$DOCKER_BINARY container run --network "$NETWORK_NAME" \
  docker.io/jwilder/dockerize \
  -wait "$URL" \
  -wait-retry-interval "$RETRY_INTERVAL" \
  -timeout "$TIMEOUT"
