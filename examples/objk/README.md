# objk demos — pure-Krypton native GUI

## Development AppKit Examples

`table_filter.ks` uses the current macOS `k:okui` APIs: retained table data
source, two columns, selection snapshots, independent click/double-click/key
handlers, a live filter field, frame persistence on close/Quit and reopen support.
Empty query restores all rows. Native arrows still navigate; Return displays a
selected item and Escape clears selection. All callbacks/data-source logic are
Krypton. Run on a macOS desktop from this checkout, not the published 2.4.8 stdlib:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 examples/objk/table_filter.ks -o /tmp/objk-table-filter
/tmp/objk-table-filter
```

First steps: [live field tutorial](../../tutorial/macos/README.md).
API/lifetimes: [AppKit event guide](../../docs/objk_appkit_events_macos.md).
Tests: `tests/macos/test_objk_table_events.k`; the full focused checker is
`scripts/check_objk_runtime_macos.ks`. These additions have no Windows/Linux
parity claim and do not change the grammar or the released compiler version.
Column/action/menu/image/frame regression coverage is in
`tests/macos/test_objk_appkit_controls.k`. Frame checks need a desktop display;
`tests/macos/test_objk_lifecycle.k` covers close veto/notification and application
open-file/reopen dispatch. The example retains its window across close and shows
it again on a reopen event; it does not implement drag/drop or document routing.

## Existing Demos

Use ordinary non-keyword callback/parameter names (`handlerBox`, `fallback`,
`scanning`), not `callback`, `default` or `go`. The development frontend rejects
these previously silent mistakes. Native `jxt` signatures remain declarations,
not function bodies; action-only Krypton bodies use `-> do`.

Native macOS apps written in Krypton, with no Objective-C source. AppKit and
Foundation remain Apple's system frameworks, accessed through Objective-K.
Start with the [Objective-K guide](../../docs/objective_k.md).

Build + run (dev tree):

    export KRYPTON_ROOT="$PWD"
    ./bootstrap/kcc_driver_macos_aarch64 examples/objk/kryedit.ks -o /tmp/objk-kryedit
    /tmp/objk-kryedit examples/objk/kryedit.ks

- **kryedit.ks** — a syntax-highlighting text editor (open a file as arg, edit, Save).
- **kshell.ks** — kcode-style shell: menu + file-table sidebar + editor, row-click loads the editor (Krypton data source + delegate).
- **highlight.ks** — colored ranges on an NSTextView via NSTextStorage.
- **term_grid.ks** — custom NSView drawRect: a terminal grid (colored cells + glyphs).
- **table.ks** — NSTableView driven by a pure-Krypton multi-method data source.
- **human_ui.ks** — `k:okui` app-facing Objective-K style: plain words for window, fields, buttons, state, clipboard, defaults, and URL open.
- **controls.ks** — `k:objk` facade: checkbox, combo box, slider, progress, defaults, clipboard, URL open.
- **windows_controls.ks** — `stdlib/objkwin.k` facade: Windows-native controls, events, shell open, text fields, theme color.
- **choc_window.ks** — `stdlib/choc.k` native UI kit smoke app, currently Windows-backed.

Note: every callback/delegate method is a plain Krypton func used as an Obj-C method
IMP — objc passes (self, _cmd, …) in x0/x1/… = Krypton's register convention.

Windows uses the same Objective-K naming style without Cocoa/libobjc. App code
should prefer `k:okui`; macOS uses `stdlib/okui.k`, Windows routes `k:okui` to
`stdlib/okui_win.k`, and both load the shared app-facing API in
`stdlib/okui_core.k`. Windows then resolves `k:objk` through
`stdlib/objkwin.k` so OKUI sits on Forge's Choc/Win32 backend. Click dispatch
passes Obj-K-shaped args: `(self, cmd, sender)`, and old no-arg handlers still
work.

Focused OKUI check:

    KRYPTON_ROOT="$PWD" bootstrap/kcc_driver_macos_aarch64 -r scripts/check_okui.ks

Windows parity check:

    kcc.exe -r scripts/check_okui.ks

## Objective-K Focus

`objective_k_focus.ks` is a macOS app built on the K-owned additions. It uses:

- `Scoreable` protocol with required methods
- runtime-checked `combine(Focus) -> Focus` dispatch
- owned work/rest models in application state
- weak peer links that do not form a cycle
- reference-counted K-owned text names
- cleanup hooks released through Quit
- OKUI controls following system theme

Build:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 -r scripts/build-objk-app.ks \
  examples/objk/objective_k_focus.ks objective_k_focus
open dist/objective_k_focus.app
```

Run native integration smoke through `scripts/check_objk_runtime_macos.ks --gui`.

## macOS K-Owned Counter

`k_owned_counter_macos.ks` uses `k:objk_runtime_macos` for its model and
`k:okui` for native controls. `.ks` and `.k` compile with the same compiler;
this demo introduces no new class syntax.

From checkout root on macOS arm64:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 -r scripts/build-objk-app.ks \
  examples/objk/k_owned_counter_macos.ks objk_counter
open dist/objk_counter.app
```

K state owns the counter model. Buttons dispatch to it and update the native
label. `Quit`/Command-Q releases state and its model, then terminates the app.
Native controls stay outside K integer fields. Do not stringify window handles;
native selectors require pointer identity.

Check integration rather than relying only on a visible window:

```sh
./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_objk_runtime_macos.ks --gui
```

This verifies actions reach value 1 and model cleanup runs exactly once.
Without `--gui`, it checks object behavior and stale-ID safety without opening
windows. Other examples may use older Apple-backed object APIs; they are not
proof that every object has migrated to the K-owned core.

Contracts and remaining work: [spec](../../spec.md),
[runtime guide](../../docs/objk_runtime_macos.md),
[grammar](../../docs/spec/grammar.md#objective-k-runtime-boundary).
