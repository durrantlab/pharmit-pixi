Pharmit
====
This repository is a fork of the Koes' lab [pharmit](https://github.com/dkoes/pharmit) from commit [49d2c0a](https://github.com/dkoes/pharmit/commit/49d2c0a573f6e58bca62f674b33874bdd42c2274).

## About this fork

We use [pixi](https://pixi.sh) to manage our build environments, and wanted
`pharmit` installable as a simple pixi dependency. This repository exists to
make that possible: it builds the pharmit CLI against a modern conda-forge
toolchain and ships it as a prebuilt conda package that can be added to a pixi
environment in one line.

The source here is a snapshot of upstream
[pharmit](https://github.com/dkoes/pharmit) at commit
[49d2c0a](https://github.com/dkoes/pharmit/commit/49d2c0a573f6e58bca62f674b33874bdd42c2274),
not a git fork — it does not track or pull upstream changes. This repository is
**not** intended for new feature development; it exists for buildability and
packaging only.

> [!WARNING]
> **The web server is not included in this build.** The upstream `server`
> command (which powers the hosted pharmit.csb.pitt.edu web interface via
> FastCGI) has been deliberately removed, because its dependencies (`cgicc`,
> `fcgi`) are not available on conda-forge. This build provides the
> command-line tools only: `pharma`, `dbcreate`, and `dbsearch`.
>
> Running `pharmit server` will print the help text and exit rather than
> starting a server. If you need the web interface, use the upstream pharmit
> distribution instead.

## Quick start

Install the prebuilt CLI into a [pixi](https://pixi.sh) project directly from a
release (Linux-64). Grab the latest `.conda` asset URL from the
[Releases page](https://github.com/durrantlab/pharmit-pixi/releases) and:

```bash
pixi add https://github.com/durrantlab/pharmit-pixi/releases/download/v0.1.3/pharmit-0.1.3-h41f06ac_0.conda
```

pixi pulls the runtime dependencies (OpenBabel, Boost, etc.) from conda-forge
automatically. 

Then:
```bash
pixi run pharmit dbsearch -dbdir=DB -in=query.json -out=hits.sdf
```


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

## Packaging (conda)

The `recipe/` directory contains a [rattler-build](https://rattler.build)
recipe that compiles `pharmit` into a relocatable conda package. This is how
the prebuilt `.conda` files attached to releases are produced. Consumers do not
need this section; it is for producing distributable artifacts.

### Files

- `recipe/recipe.yml` — the package recipe (metadata, dependencies, test).
- `recipe/build.sh` — the conda build script. It reuses the repo's `install.sh`
  by exporting the conda build `$PREFIX` (the build scripts honor an injected
  `PREFIX`, falling back to the pixi env otherwise), then copies the binary
  into `$PREFIX/bin` so it lands on `PATH` when installed.
- `recipe/variants.yml` — pins the build to an old glibc baseline (see below).

### glibc compatibility (important)

The recipe targets **glibc 2.17** via a sysroot pin in `recipe/variants.yml`:

```yaml
c_stdlib:
  - sysroot
c_stdlib_version:
  - "2.17"
```

combined with `${{ stdlib('c') }}` in the recipe's build requirements. This
decouples the build machine's glibc from the binary's glibc requirement: even
when built on a modern system (e.g. a CI runner with glibc 2.39), the resulting
binary only references glibc 2.17 symbols, so it runs on essentially any Linux
from the last decade.

**You must pass the variant file when building**, or the binary will link
against the build machine's glibc and fail on older systems with errors like
`GLIBC_2.38 not found`.

### Build the package

```bash
pixi exec rattler-build build \
  --recipe recipe/recipe.yml \
  -m recipe/variants.yml \
  --output-dir dist
```

The package is written to `dist/linux-64/pharmit-<version>-<hash>.conda`.

### Verify the glibc requirement

Confirm the built binary targets the old glibc before distributing:

```bash
cd /tmp && rm -rf px && mkdir px && cd px
unzip -o /path/to/dist/linux-64/pharmit-*.conda
tar --use-compress-program=zstd -xf pkg-*.tar.zst
objdump -T bin/pharmit | grep -oE 'GLIBC_[0-9.]+' | sort -V | tail -1
```

This should print `GLIBC_2.17` (or no higher than your target). If it shows a
newer version, the sysroot pin did not take effect — check that `-m
recipe/variants.yml` was passed and that the recipe includes
`${{ stdlib('c') }}`.

### Releasing

Releases are built automatically by the GitHub Actions workflow
(`.github/workflows/release.yml`) when a version tag is pushed:

1. Bump `version` in `recipe/recipe.yml`.
2. Commit, then tag and push:

```bash
   git commit -am "[release]: bump to 0.1.3"
   git tag v0.1.3
   git push && git push --tags
```

3. The workflow builds the package (with the glibc pin), smoke-tests it, and
   attaches the `.conda` to a GitHub Release.

Consumers then install directly from the release URL:

```bash
pixi add https://github.com/durrantlab/pharmit-pixi/releases/download/v0.1.3/pharmit-0.1.3-<hash>.conda
```

pixi reads the package's embedded dependency metadata and pulls the runtime
dependencies (OpenBabel, Boost, etc.) from conda-forge automatically.

> [!NOTE]
> The package is built for **linux-64 only**. macOS and Windows users would
> require separate platform builds.
