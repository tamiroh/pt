<p align="center">
  <img src="Support/AppIcon.png" width="128" alt="">
</p>

<h1 align="center">Pt</h1>

<p align="center">A tiny sprite. Walks, falls, floats.</p>

## Run

Requires macOS 13+ and Swift 6+.

```sh
make run
```

## Install

```sh
make app       # build build.noindex/Pt.app
make install   # copy Pt.app to /Applications
```

Set `INSTALL_DIR` to install elsewhere, e.g. `make install INSTALL_DIR=~/Applications`.
`make uninstall` removes the installed app.
