#! /usr/bin/env bash

parse_package_name() {
  TAG=$1
  match="$(echo "$TAG" | grep -oE "^(\w+-)+")"
  semver="${TAG#$match}"

  echo "${match%"-"}"
}

parse_semver() {
  TAG=$1
  match="$(echo "$TAG" | grep -oE "^(\w+-)+")"
  semver="${TAG#$match}"

  echo "${semver#v}"
}
