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

declare -A all_react_native_projects_map

for project in $all_ios_projects; do
  all_react_native_projects_map[$project]=0
done

for project in $all_android_projects; do
  all_react_native_projects_map[$project]=0
done

all_react_native_projects=${!all_react_native_projects_map[*]}

# This is a normal JS project! Copy the JS config template and exit.
if [ "$react_native" = false ]; then
  echo "No React Native projects found. Using JS CI template."

  jq -n "{}" > "$CIRCLECI_ROOT/params.json"

  envsubst < "$CIRCLECI_ROOT/js.template.yml" > "$CIRCLECI_ROOT/main.yml"

  print_generated_files

  exit 0
fi

echo "Detected React Native projects. Using React Native CI template."

# We should never skip jobs and validations on the primary branch!
if [ "$CIRCLE_BRANCH" == "$PRIMARY_BRANCH" ]; then
  affected_options=""
else
  affected_options="--affected --base=$NX_BASE --head=$NX_HEAD"
fi

[ -n "$(yarn nx show projects "$affected_options" --with-target build:ios)" ] && build_ios=true || build_ios=false
[ -n "$(yarn nx show projects "$affected_options" --with-target build:android)" ] && build_android=true || build_android=false
[ -n "$(yarn nx show projects "$affected_options" --with-target test:ios)" ] && test_ios=true || test_ios=false
[ -n "$(yarn nx show projects "$affected_options" --with-target test:android)" ] && test_android=true || test_android=false
[ -n "$(yarn nx show projects "$affected_options" --with-target e2e:ios)" ] && e2e_ios=true || e2e_ios=false
[ -n "$(yarn nx show projects "$affected_options" --with-target e2e:android)" ] && e2e_android=true || e2e_android=false

ios_semver_regex="/^(${all_ios_projects// /|})-v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/"
android_semver_regex="/^(${all_android_projects// /|})-v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/"

# Must use perl to evaluate tag matches because CircleCI regex format is
# perl-compatible, but not natively bash-compatible.
ios_tag_match=$(echo "$CIRCLE_TAG" | perl -ne "$ios_semver_regex and print \$1")
android_tag_match=$(echo "$CIRCLE_TAG" | perl -ne "$android_semver_regex and print \$1")

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
else
  affected_ios_projects=$(yarn nx show projects "$affected_options" --with-target run:ios)
fi

if [ -n "$android_tag_match" ]; then
  echo "Detected matching android project in tag: $android_tag_match"

  affected_android_projects=$android_tag_match

  build_android=true
  test_android=true
  e2e_android=true
else
  affected_android_projects=$(yarn nx show projects "$affected_options" --with-target run:android)
fi

setup_ios_apps_steps=""

if [ -n "$affected_ios_projects" ]; then
  echo "Found affected iOS projects: $affected_ios_projects"

  for project in $affected_ios_projects; do
    project_root=$(yarn nx show project "$project" | jq -r ".root")
    setup_ios_apps_steps+="
    - chiubaka/setup-ios-app:
        app-dir: $project_root"
  done
else
  echo "No affected iOS projects"
  setup_ios_apps_steps=[]
fi

setup_android_apps_steps=""

if [ -n "$affected_android_projects" ]; then
  echo "Found affected Android projects: $affected_android_projects"

  for project in $affected_android_projects; do
    project_root=$(yarn nx show project "$project" | jq -r ".root")
    setup_android_apps_steps+="
    - chiubaka/setup-android-app:
        app-dir: $project_root"
  done
else
  echo "No affected Android projects"
  setup_android_apps_steps=[]
fi

declare -A xcode_versions_map

for project in $all_ios_projects; do
  project_root=$(yarn nx show project "$project" | jq -r ".root")
  project_xcode_version=$(cat "$project_root"/.xcode-version)
  xcode_versions_map[$project_xcode_version]=0
done

xcode_versions=("${!xcode_versions_map[@]}")

num_xcode_versions=${#xcode_versions[@]}

if (( num_xcode_versions == 0 )); then
  echo "No Xcode versions configured. Will default to Xcode version specified in react-native.template.yml."
else
  xcode_version=${xcode_versions[0]}
  if (( num_xcode_versions > 1 )); then
    # shellcheck disable=2145
    echo "WARNING: Multiple Xcode versions detected: ${xcode_versions[@]}. Using $xcode_version. Additional versions may incur additional CI execution time as they cannot be pre-installed on the executor."
  fi
fi

for project in $all_react_native_projects; do
  project_root=$(yarn nx show project "$project" | jq -r ".root")
  fastlane_env=$project_root/fastlane/Fastlane.env

  if [ -n "$IOS_SIMULATOR_DEFAULT_DEVICE" ] || [ -n "$IOS_SIMULATOR_DEFAULT_OS" ]; then
    echo "WARNING: Fastlane environment variables have already been imported. Values will be overwritten and only the last imported set of values will be used. This may occur if you have multiple React Native projects and muliple Fastlane.env files."
  fi

  set -o allexport
  # shellcheck disable=1090
  source "$fastlane_env"
  set +o allexport
  echo "Imported environment variables from $fastlane_env"
done

[ -n "$xcode_version" ] && xcode_version="\"$xcode_version\"" || xcode_version=null
[ -n "$IOS_SIMULATOR_DEFAULT_DEVICE" ] && ios_simulator_device="\"$IOS_SIMULATOR_DEFAULT_DEVICE\"" || ios_simulator_device=null
[ -n "$IOS_SIMULATOR_DEFAULT_VERSION" ] && ios_simulator_version="\"$IOS_SIMULATOR_DEFAULT_VERSION\"" || ios_simulator_version=null
[ -n "$ANDROID_EMULATOR_DEFAULT_BUILD_TOOLS_VERSION" ] && android_emulator_build_tools_version="\"$ANDROID_EMULATOR_DEFAULT_BUILD_TOOLS_VERSION\"" || android_emulator_build_tools_version=null
[ -n "$ANDROID_EMULATOR_DEFAULT_PLATFORM_VERSION" ] && android_emulator_platform_version="\"$ANDROID_EMULATOR_DEFAULT_PLATFORM_VERSION\"" || android_emulator_platform_version=null

jq -n \
  "{ \
    \"xcode-version\": $xcode_version, \
    \"ios-simulator-device\": $ios_simulator_device, \
    \"ios-simulator-version\": $ios_simulator_version, \
    \"android-emulator-build-tools-version\": $android_emulator_build_tools_version, \
    \"android-emulator-platform-version\": $android_emulator_platform_version, \
    \"build-ios\": $build_ios, \
    \"build-android\": $build_android, \
    \"test-ios\": $test_ios, \
    \"test-android\": $test_android, \
    \"e2e-ios\": $e2e_ios, \
    \"e2e-android\": $e2e_android, \
  }" > "$CIRCLECI_ROOT/params.json"

IOS_SEMVER_REGEX=$ios_semver_regex \
  ANDROID_SEMVER_REGEX=$android_semver_regex \
  SETUP_IOS_APPS_STEPS=$setup_ios_apps_steps \
  SETUP_ANDROID_APPS_STEPS=$setup_android_apps_steps \
  envsubst < "$CIRCLECI_ROOT/react-native.template.yml" > "$CIRCLECI_ROOT/main.yml"

print_generated_files
