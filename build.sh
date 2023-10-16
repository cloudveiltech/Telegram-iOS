#! /bin/bash

BUILD_NUMBER=1
PROVISION_PATH=../Provision

cmd=build
build_for=sim
build_mode=debug
sign=auto

while [[ $# -gt 0 ]]; do
	case $1 in
		--sim) build_for=sim;;
		--dev) build_for=dev;;
		--deb|--debug) build_mode=debug;;
		--rel|--release) build_mode=release;;
		--sign) sign=yes;;
		--no-sign) sign=no;;
		*) cmd=$1;;
	esac
	shift
done

export USE_BAZEL_VERSION=6.3.2

args=()

if [[ $cmd != clean ]]; then
	args+=(--buildNumber=$BUILD_NUMBER)

	find submodules -name BUILD -exec sed -E -i '' 's/^([[:space:]]*)("-Werror",|"-warnings-as-errors",[[:space:]]*)$/\1#\2/' \{\} \;
	find third-party -name BUILD -exec sed -E -i '' 's/^([[:space:]]*)("-Werror",|"-warnings-as-errors",[[:space:]]*)$/\1#\2/' \{\} \;

	case "${sign},${build_mode}" in
		yes,*|auto,release) args+=(--codesigningInformationPath=${PROVISION_PATH} --configurationPath=${PROVISION_PATH}/configuration.json);;
		no,*|auto,debug) args+=(--noCodesigning --configurationPath=${PROVISION_PATH}/configuration.json);;
	esac
fi


if [[ $cmd == build ]]; then
	case "${build_for},${build_mode}" in
		sim,debug) args+=(--configuration=debug_sim_arm64);;
		sim,release) args+=(--configuration=release_sim_arm64);;
		dev,debug) args+=(--configuration=debug_arm64);;
		dev,release) args+=(--configuration=release_arm64);;
	esac

	: > build.log
	exec python3 build-system/Make/Make.py --bazel="$(which bazel)" \
		--overrideBazelVersion --overrideXcodeVersion "$cmd" "${args[@]}" 2>&1 | tee build.log
else
	exec python3 build-system/Make/Make.py --bazel="$(which bazel)" \
		--overrideBazelVersion --overrideXcodeVersion "$cmd" "${args[@]}"
fi
