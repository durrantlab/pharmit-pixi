Pharmit
====
This repository is a fork of the Koes' lab [pharmit](https://github.com/dkoes/pharmit) from commit [49d2c0a](https://github.com/dkoes/pharmit/commit/49d2c0a573f6e58bca62f674b33874bdd42c2274).

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
