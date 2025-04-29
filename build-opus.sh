#!/bin/bash

set -e


# DEBUG

DIR=cmake-build-opus-mac-debug

cmake \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_OSX_DEPLOYMENT_TARGET=12.4 \
	-G Ninja \
	-S opus \
	-B "${DIR}"

cmake --build "${DIR}" --target opus

