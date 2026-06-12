#!/usr/bin/env bash
#
# install.sh — reproducible build of the pharmit CLI (pharmacophore search)
# against a pixi-managed environment.
#
# Orchestrates, in order:
#   1. init/update the smina submodule
#   2. apply source patches (smina + pharmit) from patches/
#   3. env-side fixes      -> fix-env.sh
#   4. build libsmina.a    -> build-smina.sh
#   5. build pharmit CLI   -> build-pharmit.sh
#
# The per-step logic lives in the three scripts above (also wired as pixi
# tasks). This file only adds the bits unique to a from-scratch setup:
# submodule sync + patching + a prereq check.
#
# Run from the repo root, inside `pixi shell` or via `pixi run build`.
# Idempotent: safe to re-run.

set -euo pipefail

# ---- resolve paths -------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# the sub-scripts key off PIXI_PROJECT_ROOT; set it when not already provided
# (e.g. when running ./install.sh directly rather than via `pixi run`)
export PIXI_PROJECT_ROOT="${PIXI_PROJECT_ROOT:-$REPO_ROOT}"

PREFIX="${PREFIX:-$PIXI_PROJECT_ROOT/.pixi/envs/default}"
SMINA_DIR="$REPO_ROOT/external/smina"
PATCH_DIR="$REPO_ROOT/patches"

if [[ ! -d "$PREFIX" ]]; then
  echo "ERROR: pixi env not found at $PREFIX" >&2
  echo "Run 'pixi install' first." >&2
  exit 1
fi

echo "==> repo:   $REPO_ROOT"
echo "==> prefix: $PREFIX"

# ---- 1. submodule --------------------------------------------------------
echo "==> [1/5] syncing smina submodule"
git submodule update --init --recursive

# ---- helper: apply a patch only if not already applied -------------------
apply_patch() {
  local dir="$1" patch="$2"
  if [[ ! -f "$patch" ]]; then
    echo "    WARN: patch not found: $patch (skipping)" >&2
    return 0
  fi
  if git -C "$dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "    already applied: $(basename "$patch")"
  elif git -C "$dir" apply --check "$patch" >/dev/null 2>&1; then
    git -C "$dir" apply "$patch"
    echo "    applied: $(basename "$patch")"
  else
    echo "    WARN: cannot cleanly apply $(basename "$patch") — may already be applied or conflict" >&2
  fi
}

# ---- 2. source patches ---------------------------------------------------
echo "==> [2/5] applying source patches"
apply_patch "$SMINA_DIR" "$PATCH_DIR/smina/smina-01-filesystem-api.patch"
apply_patch "$SMINA_DIR" "$PATCH_DIR/smina/smina-02-cxx14.patch"
apply_patch "$REPO_ROOT" "$PATCH_DIR/pharmit/pharmit-01-cmakelists-no-server.patch"
apply_patch "$REPO_ROOT" "$PATCH_DIR/pharmit/pharmit-02-main-no-server.patch"

# ---- 3-5. delegate to the per-step scripts -------------------------------
echo "==> [3/5] applying environment fixes (fix-env.sh)"
bash "$REPO_ROOT/fix-env.sh"

echo "==> [4/5] building libsmina.a (build-smina.sh)"
bash "$REPO_ROOT/build-smina.sh"

echo "==> [5/5] building pharmit (build-pharmit.sh)"
bash "$REPO_ROOT/build-pharmit.sh"

echo
echo "==> DONE. Binary at: $REPO_ROOT/build/pharmit"
echo "    Test with: ./build/pharmit"
