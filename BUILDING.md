## Building from source

This builds the `pharmit` CLI (and its bundled `smina` minimization library)
from source using [pixi](https://pixi.sh) to manage the toolchain and
dependencies.

### Prerequisites

- [pixi](https://pixi.sh) installed
- A C/C++ compiler toolchain (provided through pixi; see `pixi.toml`)

### Clone with submodules

`smina` is vendored as a git submodule under `external/smina` (pinned to a
specific upstream commit). You must clone recursively so the submodule is
populated:

```bash
git clone --recursive https://github.com/durrantlab/pharmit-pixi.git
cd pharmit-pixi
```

If you already cloned without `--recursive`, initialize the submodule:

```bash
git submodule update --init --recursive
```

### Build

```bash
pixi run build
```

This runs `install.sh`, which orchestrates the full build:

1. Initializes the `smina` submodule (if needed).
2. Applies source patches from `patches/` to `smina` and `pharmit` (these adapt
   the code to a modern toolchain and remove the web server).
3. Runs `fix-env.sh` to apply environment-side fixes to the pixi environment
   (header symlinks, LEMON GLPK backend, OpenBabel library paths).
4. Builds the `smina` minimization library (`build-smina.sh`).
5. Builds the `pharmit` binary (`build-pharmit.sh`).

The resulting binary is at `build/pharmit`.

### Test

```bash
pixi run test
```

This runs a smoke test that exercises the full pipeline (`pharma` → `dbcreate`
→ `dbsearch`) on a molecule fetched from PubChem, confirming the binary builds
and runs correctly. Requires network access.

### Notes on the source layout

- `src/` contains the pristine pharmit source; patches are applied at build
  time and the source is not modified in the repository.
- `external/smina/` is the smina submodule. The committed pointer references a
  clean upstream commit; the patches in `patches/smina/` recreate the necessary
  edits on top of it at build time. Do not commit changes to the submodule
  pointer after building.
- `patches/` holds the source patches, separated into `smina/` and `pharmit/`
  subdirectories.
