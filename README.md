# pt

A small desktop mascot for macOS.

## Run

Requires macOS 13+ and Swift 6+.

```sh
swift run pt
```

## Install

```sh
make app       # build build/pt.app
make install   # copy pt.app to /Applications
```

Set `INSTALL_DIR` to install elsewhere, e.g. `make install INSTALL_DIR=~/Applications`.
`make uninstall` removes the installed app.

## Development

```sh
swift build
swift test
swift build -c release
```
