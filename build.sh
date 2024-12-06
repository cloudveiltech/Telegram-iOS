#! /bin/bash

# This should be in version control.
BUILD_NUMBER=1


# This is the path to the configuration and mobile provisioning profiles used
# for `distribution` builds. The mobile provisioning profiles must be `Apple
# Distribution` profiles.
PROVISION_PATH_DIST=../Provision

# This is the path to the configuration and mobile provisioning profiles used
# for `development` builds. The mobile provisioning must be `Apple Development`
# profiles, and must include every device id the app will be installed on.
PROVISION_PATH_DEV=../ProvisionDebug


# The operation we want to do. Well supported options currently are `build` or
# `clean`.
cmd=build

# What kinds of devices you will install the build on. Supports `simulator`,
# `development`, or `distribution`. `simulator` builds aren't signed.
# `development` builds allow debuggers to connect to the running app, but can't
# be submitted to TestFlight. `distribution` builds can be submitted to
# TestFlight, or released on the App Store, but don't allow debugging tools to
# connect to the running app.
build_for=simulator

# What purpose the build is intended for. `debug` builds are for debugging
# (obviously). They have debug symbols embedded in the IPA, and are not
# optimized. `release` builds are for wide distribution to non-testers
# (obviously). They are optimized, and have the debugging symbols stored
# separately from the IPA.
build_mode=debug

# parse the command line options
while [[ $# -gt 0 ]]; do
	case $1 in
		--sim) build_for=simulator;;
		--dev) build_for=development;;
		--dist) build_for=distribution;;
		--deb|--debug) build_mode=debug;;
		--rel|--release) build_mode=release;;
		*) cmd=$1;;
	esac
	shift
done

# select the bazel version we will use
export USE_BAZEL_VERSION=6.3.2

args=()

# Override Bazel's logic for whether to allow debuggers control over running
# apps. The default follows build_mode, and wouldn't let us build debug builds
# for TestFlight. This flag has to be added to the arguments before the command.
if [[ $cmd == build ]]; then
	case $build_for in
		simulator|development) args+=(--bazelArguments=--define=apple.add_debugger_entitlement=yes);;
		distribution) args+=(--bazelArguments=--define=apple.add_debugger_entitlement=no);;
	esac
fi

args+=($cmd)

if [[ $cmd != clean ]]; then
	args+=(--buildNumber=$BUILD_NUMBER)

	# Don't treat warings as errors.
	find submodules -name BUILD -exec sed -E -i '' 's/^([[:space:]]*)("-Werror",|"-warnings-as-errors",[[:space:]]*)$/\1#\2/' \{\} \;
	find third-party -name BUILD -exec sed -E -i '' 's/^([[:space:]]*)("-Werror",|"-warnings-as-errors",[[:space:]]*)$/\1#\2/' \{\} \;

	# Add the build config json and code signing config to the arguments.
	case $build_for in
		simulator) args+=(--noCodesigning --configurationPath=${PROVISION_PATH_DEV}/configuration.json);;
		development) args+=(--codesigningInformationPath=${PROVISION_PATH_DEV} --configurationPath=${PROVISION_PATH_DEV}/configuration.json);;
		distribution) args+=(--codesigningInformationPath=${PROVISION_PATH_DIST} --configurationPath=${PROVISION_PATH_DIST}/configuration.json);;
	esac
fi


if [[ $cmd == build ]]; then
	# Select the build mode.
	case "${build_for},${build_mode}" in
		simulator,debug) args+=(--configuration=debug_sim_arm64);;
		simulator,release) args+=(--configuration=release_sim_arm64);;
		*,debug) args+=(--configuration=debug_arm64);;
		*,release) args+=(--configuration=release_arm64);;
	esac

	# Run the build
	: > build.log
	exec python3 build-system/Make/Make.py --bazel="$(which bazel)" \
		--overrideBazelVersion --overrideXcodeVersion "${args[@]}" 2>&1 | tee build.log
else
	exec python3 build-system/Make/Make.py --bazel="$(which bazel)" \
		--overrideBazelVersion --overrideXcodeVersion "${args[@]}"
fi
