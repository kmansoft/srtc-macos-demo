#!/bin/bash

set -e


# DEBUG

DIR=cmake-build-opus-mac-debug

cmake \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-G Ninja \
	-S opus \
	-B "${DIR}"

cmake --build "${DIR}" --target opus

