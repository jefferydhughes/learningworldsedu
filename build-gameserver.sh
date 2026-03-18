#!/bin/bash
#
# Blip Game Server — Standalone Build Script (no Docker required)
#
# Prerequisites:
#   - cmake (3.20+), ninja, gcc/g++ (11+) OR clang/clang++
#   - git, curl (for downloading dependencies)
#
# Usage:
#   ./build-gameserver.sh [--debug]
#
# Output:
#   ./gameserver-build/gameserver  (the compiled binary)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_TYPE="Release"
BUILD_DIR="${SCRIPT_DIR}/gameserver-build"

if [[ "${1:-}" == "--debug" ]]; then
    BUILD_TYPE="Debug"
fi

echo "=== Blip Game Server Build ==="
echo "Build type: ${BUILD_TYPE}"
echo "Repo root:  ${SCRIPT_DIR}"
echo ""

# --------------------------------------------------
# Step 1: Check prerequisites
# --------------------------------------------------
echo "[1/4] Checking prerequisites..."

for cmd in cmake ninja gcc g++ git; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' is not installed. Install it and retry."
        exit 1
    fi
done

echo "  All tools found."

# --------------------------------------------------
# Step 2: Build libluau if missing
# --------------------------------------------------
LUAU_DIR="${SCRIPT_DIR}/deps/libluau/_active_/prebuilt/linux/x86_64"

if [ ! -f "${LUAU_DIR}/lib-${BUILD_TYPE}/libluau.a" ]; then
    echo "[2/4] Building libluau from source..."

    LUAU_TMP="${SCRIPT_DIR}/.build-deps/luau-src"
    rm -rf "${LUAU_TMP}"
    mkdir -p "${LUAU_TMP}"

    # Clone Luau source (tag 0.661)
    git clone --depth 1 --branch 0.661 https://github.com/luau-lang/luau.git "${LUAU_TMP}" 2>&1

    # Build with cmake
    mkdir -p "${LUAU_TMP}/build"
    cmake -S "${LUAU_TMP}" -B "${LUAU_TMP}/build" \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DLUAU_BUILD_CLI=OFF \
        -DLUAU_BUILD_TESTS=OFF \
        -DLUAU_BUILD_WEB=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -G Ninja 2>&1

    ninja -C "${LUAU_TMP}/build" -j"$(nproc)" 2>&1

    # Create output directory structure
    mkdir -p "${LUAU_DIR}/lib-Release" "${LUAU_DIR}/lib-Debug" "${LUAU_DIR}/include"

    # Merge all static libraries into one
    MERGE_DIR="${LUAU_TMP}/build/merge"
    mkdir -p "${MERGE_DIR}"
    cd "${MERGE_DIR}"

    for lib in "${LUAU_TMP}/build"/libLuau.*.a; do
        ar x "$lib"
    done
    ar rcs libluau.a *.o

    cp libluau.a "${LUAU_DIR}/lib-Release/libluau.a"
    cp libluau.a "${LUAU_DIR}/lib-Debug/libluau.a"

    # Copy headers (including CLI headers needed by the codebase)
    for dir in Common Ast Compiler Config Analysis CodeGen EqSat VM CLI; do
        if [ -d "${LUAU_TMP}/${dir}/include" ]; then
            cp -r "${LUAU_TMP}/${dir}/include/"* "${LUAU_DIR}/include/"
        fi
    done

    cd "${SCRIPT_DIR}"
    echo "  libluau built successfully."
else
    echo "[2/4] libluau already present — skipping."
fi

# --------------------------------------------------
# Step 3: Build libpng if missing
# --------------------------------------------------
PNG_DIR="${SCRIPT_DIR}/deps/libpng/_active_/prebuilt/linux/x86_64"

if [ ! -f "${PNG_DIR}/lib-${BUILD_TYPE}/libpng.a" ]; then
    echo "[3/4] Building libpng from source..."

    PNG_TMP="${SCRIPT_DIR}/.build-deps/libpng-src"
    rm -rf "${PNG_TMP}"
    mkdir -p "${PNG_TMP}"

    git clone --depth 1 --branch v1.6.47 https://github.com/pnggroup/libpng.git "${PNG_TMP}" 2>&1

    cp "${PNG_TMP}/scripts/pnglibconf.h.prebuilt" "${PNG_TMP}/pnglibconf.h"

    mkdir -p "${PNG_TMP}/build"
    cmake -S "${PNG_TMP}" -B "${PNG_TMP}/build" \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DPNG_SHARED=OFF \
        -DPNG_TESTS=OFF \
        -DPNG_TOOLS=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -G Ninja 2>&1

    ninja -C "${PNG_TMP}/build" -j"$(nproc)" 2>&1

    # Create output directory structure
    mkdir -p "${PNG_DIR}/lib-Release" "${PNG_DIR}/lib-Debug" "${PNG_DIR}/include"

    cp "${PNG_TMP}/build/libpng16.a" "${PNG_DIR}/lib-Release/libpng.a"
    cp "${PNG_TMP}/build/libpng16.a" "${PNG_DIR}/lib-Debug/libpng.a"

    cp "${PNG_TMP}/png.h" "${PNG_DIR}/include/"
    cp "${PNG_TMP}/pngconf.h" "${PNG_DIR}/include/"
    cp "${PNG_TMP}/build/pnglibconf.h" "${PNG_DIR}/include/"

    echo "  libpng built successfully."
else
    echo "[3/4] libpng already present — skipping."
fi

# --------------------------------------------------
# Step 4: Build the game server
# --------------------------------------------------
echo "[4/4] Building game server..."

export CUBZH_TARGETARCH=amd64

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cmake -S "${SCRIPT_DIR}/common/VXGameServer" \
      -B "${BUILD_DIR}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -G Ninja 2>&1

ninja -C "${BUILD_DIR}" -j"$(nproc)" 2>&1

# --------------------------------------------------
# Done
# --------------------------------------------------
BINARY="${BUILD_DIR}/gameserver"
if [ -f "${BINARY}" ]; then
    echo ""
    echo "=== Build Successful ==="
    echo "Binary: ${BINARY}"
    echo "Size:   $(du -h "${BINARY}" | cut -f1)"
    echo ""
    echo "Usage:"
    echo "  ${BINARY} <mode> <worldID> <serverIDPrefix> <authToken> [maxPlayers]"
    echo ""
    echo "Example:"
    echo "  HOSTNAME=\$(hostname) ${BINARY} dev my-world-id eu-1- my-auth-token 8"
else
    echo "ERROR: Build failed — binary not found."
    exit 1
fi
