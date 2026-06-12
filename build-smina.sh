#!/usr/bin/env bash
set -euo pipefail

# self-locate: use pixi's var if present, else derive from this script's dir
ROOT="${PIXI_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PREFIX="${PREFIX:-$ROOT/.pixi/envs/default}"
SMINA="$ROOT/external/smina"

# disable smina's bundled Eigen so its #include "Eigen/Core" resolves to pixi eigen3
[ -d "$SMINA/src/lib/Eigen" ] && mv "$SMINA/src/lib/Eigen" "$SMINA/src/lib/Eigen.disabled" || true

# fresh configure so flags are re-read (avoids stale CMAKE_CXX_FLAGS cache)
rm -rf "$SMINA/build"

# eigen3 passed explicitly via CMAKE_CXX_FLAGS: it's a subdir of include/ and
# cmake will silently drop it if buried alongside the parent include path.
cmake -S "$SMINA" -B "$SMINA/build" \
  -DCMAKE_PREFIX_PATH="$PREFIX" -DCMAKE_BUILD_TYPE=Release \
  -DOPENBABEL3_INCLUDE_DIR="$PREFIX/include/openbabel3" \
  -DOPENBABEL3_LIBRARIES="$PREFIX/lib/libopenbabel.so" \
  -DBoost_INCLUDE_DIR="$PREFIX/include" -DBoost_NO_BOOST_CMAKE=ON \
  -DCMAKE_CXX_FLAGS="-I$PREFIX/include -I$PREFIX/include/eigen3 -DBOOST_TIMER_ENABLE_DEPRECATED -DBOOST_ALLOW_DEPRECATED_HEADERS -DEIGEN_MAX_ALIGN_BYTES=0 -DEIGEN_MAX_STATIC_ALIGN_BYTES=0 -DEIGEN_NO_DEBUG"

cmake --build "$SMINA/build" --target libsmina -j"${JOBS:-8}"

[ -f "$SMINA/build/libsmina.a" ] && echo "ok: libsmina.a" || { echo "ERROR: libsmina.a not built" >&2; exit 1; }
