#! /usr/bin/env bash

MONOREPO_ROOT="${CIRCLE_WORKING_DIRECTORY/#\~/$HOME}"
CIRCLECI_ROOT="$MONOREPO_ROOT/.circleci"

print_generated_files() {
  echo "Contents of $CIRCLECI_ROOT/main.yml:"
  cat "$CIRCLECI_ROOT/main.yml"

  echo "Contents of $CIRCLECI_ROOT/params.json:"
  cat "$CIRCLECI_ROOT/params.json"
}

all_ios_projects=$(yarn nx show projects --with-target run:ios)
all_android_projects=$(yarn nx show projects --with-target run:android)

{ [ -n "$all_ios_projects" ] || [ -n "$all_android_projects" ]; } && react_native=true || react_native=false

# This is a normal JS project! Copy the JS config template and exit.
if [ "$react_native" = false ]; then
  echo "No React Native projects found. Using JS CI template."

  jq -n "{}" > "$CIRCLECI_ROOT/params.json"

  envsubst < "$CIRCLECI_ROOT/js.yml.template" > "$CIRCLECI_ROOT/main.yml"

  print_generated_files

  exit 0
fi

echo "Detected React Native projects. Using React Native CI template."

[ -n "$(yarn nx show projects --affected --with-target build:ios)" ] && build_ios=true || build_ios=false
[ -n "$(yarn nx show projects --affected --with-target build:android)" ] && build_android=true || build_android=false
[ -n "$(yarn nx show projects --affected --with-target test:ios)" ] && test_ios=true || test_ios=false
[ -n "$(yarn nx show projects --affected --with-target test:android)" ] && test_android=true || test_android=false
[ -n "$(yarn nx show projects --affected --with-target e2e:ios)" ] && e2e_ios=true || e2e_ios=false
[ -n "$(yarn nx show projects --affected --with-target e2e:android)" ] && e2e_android=true || e2e_android=false
[ -n "$(yarn nx show projects --affected --with-target deploy:ios)" ] && deploy_ios=true || deploy_ios=false
[ -n "$(yarn nx show projects --affected --with-target deploy:android)" ] && deploy_android=true || deploy_android=false

ios_semver_regex="/^(${all_ios_projects// /|})-v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/"
android_semver_regex="/^(${all_android_projects// /|})-v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/"

# Must use perl to evaluate tag matches because CircleCI regex format is
# perl-compatible, but not natively bash-compatible.
ios_tag_match=$(echo $CIRCLE_TAG | perl -ne "$ios_semver_regex and print \$1")
android_tag_match=$(echo $CIRCLE_TAG | perl -ne "$android_semver_regex and print \$1")

# If this is a tag-based deployment, for each platform, if that platform's semver
# regex is matched:
#   1. The only affected project for this platform is the project referenced in the
#      tag
#   2. All jobs for the affected platform should be enabled
if [ -n "$ios_tag_match" ]; then
  echo "Detected matching iOS project in tag: $ios_tag_match"

  affected_ios_projects=$ios_tag_match

  build_ios=true
  test_ios=true
  e2e_ios=true
  deploy_ios=true
else
  affected_ios_projects=$(yarn nx show projects --affected --with-target run:ios)
fi

if [ -n "$android_tag_match" ]; then
  echo "Detected matching android project in tag: $android_tag_match"

  affected_android_projects=$android_tag_match

  build_android=true
  test_android=true
  e2e_android=true
  deploy_android=true
else
  affected_android_projects=$(yarn nx show projects --affected --with-target run:android)
fi

setup_ios_apps=""

if [ -n "$affected_ios_projects" ]; then
  echo "Found affected iOS projects: $affected_ios_projects"

  for project in $affected_ios_projects; do
    project_root=$(yarn nx show project $project | jq -r ".root")
    setup_ios_apps+="
    - chiubaka/setup-ios-app:
        app-dir: $project_root"
  done
else
  echo "No affected iOS projects"
  setup_ios_apps=[]
fi

setup_android_apps=""

if [ -n "$affected_android_projects" ]; then
  echo "Found affected Android projects: $affected_android_projects"

  for project in $affected_android_projects; do
    project_root=$(yarn nx show project $project | jq -r ".root")
    setup_android_apps+="
    - chiubaka/setup-android-app:
        app-dir: $project_root"
  done
else
  echo "No affected Android projects"
  setup_android_apps=[]
fi

jq -n \
  "{ \
    \"build-ios\": $build_ios, \
    \"build-android\": $build_android, \
    \"test-ios\": $test_ios, \
    \"test-android\": $test_android, \
    \"e2e-ios\": $e2e_ios, \
    \"e2e-android\": $e2e_android, \
    \"deploy-ios\": $deploy_ios, \
    \"deploy-android\": $deploy_android \
  }" > "$CIRCLECI_ROOT/params.json"

IOS_SEMVER_REGEX=$ios_semver_regex \
  ANDROID_SEMVER_REGEX=$android_semver_regex \
  SETUP_IOS_APPS=$setup_ios_apps \
  SETUP_ANDROID_APPS=$setup_android_apps \
  envsubst < "$CIRCLECI_ROOT/react-native.yml.template" > "$CIRCLECI_ROOT/main.yml"

print_generated_files
