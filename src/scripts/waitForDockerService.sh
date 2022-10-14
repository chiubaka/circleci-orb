#! /usr/bin/env bash
set -e

DOCKER_BINARY=${DOCKER_BINARY:-docker}

sleep 5

$DOCKER_BINARY container run --network "container:$CONTAINER_NAME" \
  docker.io/jwilder/dockerize \
  -wait "$URL" \
  -wait-retry-interval "$RETRY_INTERVAL" \
  -timeout "$TIMEOUT"
