#! /usr/bin/env bash

MONOREPO_ROOT=$CIRCLE_WORKING_DIRECTORY
CIRCLECI_ROOT="$MONOREPO_ROOT/.circleci"

build_ios=false
build_android=false
test_ios=false
test_android=false
e2e_ios=false
e2e_android=false
deploy_ios=false
deploy_android=false

affected_projects=`yarn nx show projects --affected`

for project in $affected_projects; do
  targets=$(yarn nx show project $project | jq -r ".targets | keys[]")

  if [[ "$targets" =~ .*"build:ios:ci".* ]]; then
    build_ios=true
  fi

  if [[ "$targets" =~ .*"build:android:ci".* ]]; then
    build_android=true
  fi

  if [[ "$targets" =~ .*"test:ios:ci".* ]]; then
    test_android=true
  fi

  if [[ "$targets" =~ .*"test:android:ci".* ]]; then
    test_android=true
  fi

  if [[ "$targets" =~ .*"e2e:ios:ci".* ]]; then
    e2e_ios=true
  fi

  if [[ "$targets" =~ .*"e2e:android:ci".* ]]; then
    e2e_android=true
  fi

  if [[ "$targets" =~ .*"deploy:ios:ci".* ]]; then
    deploy_android=true
  fi

  if [[ "$targets" =~ .*"deploy:android:ci".* ]]; then
    deploy_android=true
  fi
done

ios_projects=$(yarn nx show projects --with-target run:ios --json | jq -r -c ".[]")
android_projects=$(yarn nx show projects --with-target run:android --json | jq -r -c ".[]")

setup_ios_apps=""
react_native=false

if [ ! -z "$ios_projects" ]; then
  react_native=true
  for project in $ios_projects; do
    project_root=$(yarn nx show project $project | jq -r ".root")
    setup_ios_apps+="
    - chiubaka/setup-ios-app:
        app-dir: $project_root"
  done
else
  setup_ios_apps=[]
fi

setup_android_apps=""

if [ ! -z "$android_projects" ]; then
  react_native=true
  for project in $android_projects; do
    project_root=$(yarn nx show project $project | jq -r ".root")
    setup_android_apps+="
    - chiubaka/setup-android-app:
        app-dir: $project_root"
  done
else
  setup_android_apps=[]
fi

react_native=false

if [ "$react_native" = true ]; then
  jq -n \
    "{ \
      \"react-native\": $react_native, \
      \"build-ios\": $build_ios, \
      \"build-android\": $build_android, \
      \"test-ios\": $test_ios, \
      \"test-android\": $test_android, \
      \"e2e-ios\": $e2e_ios, \
      \"e2e-android\": $e2e_android, \
      \"deploy-ios\": $deploy_ios, \
      \"deploy-android\": $deploy_android \
    }" > "$CIRCLECI_ROOT/params.json"

  ios_semver_regex="/^(${ios_projects// /|})-v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/"
  android_semver_regex="/^(${android_projects// /|})-v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/"

  IOS_SEMVER_REGEX=$ios_semver_regex \
    ANDROID_SEMVER_REGEX=$android_semver_regex \
    SETUP_IOS_APPS=$setup_ios_apps \
    SETUP_ANDROID_APPS=$setup_android_apps \
    envsubst < "$CIRCLECI_ROOT/react-native.yml.template" > "$CIRCLECI_ROOT/main.yml"
else
  jq -n "{}" > "$CIRCLECI_ROOT/params.json"

  envsubst < "$CIRCLECI_ROOT/js.yml.template" > "$CIRCLECI_ROOT/main.yml"
fi

cat "$CIRCLECI_ROOT/main.yml"
cat "$CIRCLECI_ROOT/params.json"
