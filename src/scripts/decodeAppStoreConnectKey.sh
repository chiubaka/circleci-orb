#! /usr/bin/env bash

mkdir -p $SECRETS_DIR
echo $APP_STORE_CONNECT_KEY | base64 -d -o "$SECRETS_DIR/app-store-connect-key.p8"
