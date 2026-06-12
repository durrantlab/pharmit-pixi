#!/usr/bin/env bash
# Re-apply environment-side fixes that live inside the pixi env.
# These do not survive `pixi install` / re-solve, so they are re-applied here
# (and by install.sh) after the env is solved and before building.
set -uo pipefail   # NOTE: no `-e` — we handle each step's failure explicitly

# self-locate: use pixi's var if set, else derive from this script's dir
ROOT="${PIXI_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PREFIX="${PREFIX:-$ROOT/.pixi/envs/default}"

if [[ ! -d "$PREFIX" ]]; then
  echo "ERROR: pixi env not found at $PREFIX (run 'pixi install')" >&2
  exit 1
fi

# 1. BitMagic: pharmit includes <bm/...>; conda ships headers under include/bitmagic/
if [[ ! -e "$PREFIX/include/bm" ]]; then
  ln -sf bitmagic "$PREFIX/include/bm"
  echo "    symlink: include/bm -> bitmagic"
else
  echo "    ok: include/bm"
fi

# 2. zlib: openbabel's cmake export references an unversioned libz.so that
#    conda doesn't ship (only libz.so.N). Create the symlink.
if [[ ! -e "$PREFIX/lib/libz.so" ]]; then
  zso="$(ls "$PREFIX"/lib/libz.so.* 2>/dev/null | grep -E 'libz\.so\.[0-9]+$' | head -1)"
  if [[ -n "$zso" ]]; then
    ln -sf "$(basename "$zso")" "$PREFIX/lib/libz.so"
    echo "    symlink: lib/libz.so -> $(basename "$zso")"
  else
    echo "    WARN: no libz.so.N found to symlink" >&2
  fi
else
  echo "    ok: lib/libz.so"
fi

# 3. LEMON: conda's lp.h defaults Lp/Mip to ClpLp/CbcMip (backends not built in);
#    repoint the defaults to the GLPK backend that IS available.
LP="$PREFIX/include/lemon/lp.h"
if [[ -f "$LP" ]]; then
  if grep -q 'typedef ClpLp Lp;' "$LP"; then
    sed -i 's/typedef ClpLp Lp;/typedef GlpkLp Lp;/; s/typedef CbcMip Mip;/typedef GlpkMip Mip;/' "$LP"
    echo "    patched: lemon/lp.h (Clp/Cbc -> Glpk)"
  else
    echo "    ok: lemon/lp.h (already Glpk)"
  fi
else
  echo "    WARN: lemon/lp.h not found — is lemon installed?" >&2
fi
# 4. OpenBabel cmake export hardcodes a build-machine libm.so path that doesn't
#    exist here. Replace it with bare "m" so it links system libm via -lm.
OB_EXPORT="$PREFIX/lib/cmake/openbabel3/OpenBabel3_EXPORTS.cmake"
if [[ -f "$OB_EXPORT" ]] && grep -q 'feedstock_root.*libm\.so' "$OB_EXPORT"; then
  sed -i 's|/home/conda/feedstock_root/build_artifacts/openbabel_[0-9]*/_build_env/x86_64-conda-linux-gnu/sysroot/usr/lib/libm\.so|m|g' "$OB_EXPORT"
  echo "    patched: openbabel export (libm.so path -> m)"
else
  echo "    ok: openbabel export (libm already fixed or not present)"
fi
echo "env fixes applied"
