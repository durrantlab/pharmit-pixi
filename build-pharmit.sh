#!/usr/bin/env bash
set -euo pipefail

ROOT="${PIXI_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PREFIX="${PREFIX:-$ROOT/.pixi/envs/default}"

rm -rf "$ROOT/build"

cmake -S "$ROOT/src" -B "$ROOT/build" \
  -DCMAKE_PREFIX_PATH="$PREFIX" -DCMAKE_BUILD_TYPE=Release \
  -DSMINA_DIR="$ROOT/external/smina" \
  -DOPENBABEL3_INCLUDE_DIR="$PREFIX/include/openbabel3" \
  -DOPENBABEL3_LIBRARIES="$PREFIX/lib/libopenbabel.so" \
  -DBoost_INCLUDE_DIR="$PREFIX/include" -DBoost_NO_BOOST_CMAKE=ON \
  -DSKIP_REGISTERZINC=1 -Dbm_SOURCE_DIR="$PREFIX/include" \
  -DCMAKE_CXX_FLAGS="-I$PREFIX/include -I$PREFIX/include/eigen3 -DBOOST_TIMER_ENABLE_DEPRECATED -DBOOST_ALLOW_DEPRECATED_HEADERS -DEIGEN_MAX_ALIGN_BYTES=0 -DEIGEN_MAX_STATIC_ALIGN_BYTES=0 -DEIGEN_NO_DEBUG"

cmake --build "$ROOT/build" -j"${JOBS:-8}"

[ -f "$ROOT/build/pharmit" ] && echo "ok: pharmit built at $ROOT/build/pharmit" || { echo "ERROR: pharmit not built" >&2; exit 1; }
