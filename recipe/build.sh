#!/usr/bin/env bash
# rattler-build build script for pharmit.
# Reuses the repo's install.sh wholesale — the only conda-specific bits are:
#   - $PREFIX is already set by rattler-build (the conda build prefix); we export
#     it so install.sh and its sub-scripts build against it instead of .pixi/.
#   - after the build, copy the binary into $PREFIX/bin so it lands on PATH for
#     anyone who installs the package.
set -euo pipefail

cd "${SRC_DIR:-$PWD}"

# rattler-build sets PREFIX; export so the sub-scripts (which read
# PREFIX="${PREFIX:-$ROOT/.pixi/envs/default}") pick it up.
export PREFIX

# ensure the smina submodule is present (no-op if the source already has it)
if [[ ! -e external/smina/CMakeLists.txt ]]; then
  git submodule update --init --recursive
fi

# run the exact same build the repo uses locally
bash install.sh

# the one conda-specific step: install onto PATH
mkdir -p "$PREFIX/bin"
cp build/pharmit "$PREFIX/bin/pharmit"
chmod +x "$PREFIX/bin/pharmit"
echo "==> installed: $PREFIX/bin/pharmit"
