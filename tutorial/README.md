# Krypton Tutorials

The core course is the numbered `01_hello_world.k` through
`34_browser_hn.k` files in this directory. They cover language basics,
collections, modules, and the browser/web path. Published website lessons and
their WASM assets are a separate deployment artifact.

## Native macOS Track

Start with [Objective-K live fields and tables](macos/README.md).
It uses the current development AppKit adapter, not the installed 2.4.8 API.
These lessons require a macOS desktop and are not browser/WASM lessons.
Do not add them to the website's cross-platform lesson export unconditionally.

The native track changes no language grammar and makes no Windows/Linux parity
claim. Ordinary functions/imports compose an application; imported K-owned
`objk object`/`objk protocol` declarations still have separate compiler limits.
