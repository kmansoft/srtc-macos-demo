#!/bin/bash

set -e


# DEBUG

DIR=cmake-build-srtc-mac-debug

cmake \
	-DCMAKE_BUILD_TYPE=Debug \
	-G Ninja \
	-S srtc \
	-B "${DIR}"

cmake --build "${DIR}" --target srtc

# Stable path for XCode

if [ -z "HOMEBREW_CELLAR" ]
then
	echo "***** Error: HomeBrew does not seem to be installed"
	exit 1
fi

LIBPATH=$(readlink -f $HOMEBREW_CELLAR/openssl@3/**/lib)
if [ -z "$LIBPATH" ]
then
	echo "*** Error: OpenSSL does not seem to be installed, please 'brew install openssl'"
	exit 1
fi

ln -s "$LIBPATH" "${DIR}/openssl-lib"
