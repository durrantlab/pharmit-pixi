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

> [!NOTE]
> The package is built for **linux-64 only**. macOS and Windows users would
> require separate platform builds.
