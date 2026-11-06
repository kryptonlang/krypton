# Objective-K: Start Here

Objective-K is Krypton's object and native-application layer. It uses the same
`kcc` compiler as Krypton and KryptScript, not a separate interpreter or an
Objective-C compiler. `.k` and `.ks` share syntax. Normal functions and modules
can be split across files and combined with `import`.

This guide describes the current source checkout. Published macOS 2.4.8 and a
development checkout are not interchangeable: the table/key/live-field APIs
below were committed after that release. There is no version bump implied by
this documentation. Use the checkout driver and stdlib when testing them.

## Three Layers, Different Responsibilities

| Layer | Entry point | Owns or provides |
| --- | --- | --- |
| K-owned object model | `k:objk_runtime_macos` or compiler `objk` declarations | Classes, protocols, dispatch, fields, owned/weak references, text and cleanup. |
| Application facade on macOS | `k:okui`, exposing `k:objk` | Native controls, windows, menus and documented events. |
| macOS platform adapter | `stdlib/choc_macos.k`, using `k:objc` | AppKit/Foundation/libobjc calls, native objects and IMP callbacks. |

The K-owned model is not an AppKit object. Keep native window/control pointers
out of its integer fields. A K-owned model can drive a native UI without making
that UI part of its arena or ownership system.

The core does not import Apple's object frameworks. The macOS UI adapter does:
it links to Apple's libobjc, Foundation and AppKit. Objective-K replaces the
need for Objective-C source/compilation, not Apple's system libraries. These
examples do not generate C/Objective-C or invoke Clang.

Windows uses its separate OKUI/Objective-K/Choc adapters. The new macOS APIs
are not evidence of Windows support. Linux/BSD GUI parity remains future work.
Do not replace platform imports merely because two APIs have similar names.

## Build From This Checkout

Run from the Krypton repository root on macOS arm64:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 tutorial/macos/01_live_field.ks -o /tmp/objk-live-field
/tmp/objk-live-field
```

The explicit driver path avoids confusing Apple's unrelated Kerberos `kcc`
with Krypton's compiler. `KRYPTON_ROOT` selects this checkout's stdlib/headers;
it must be present in the shell or build process invoking the driver.
Compiling alone creates an executable, not an App Store-ready app bundle.
The test demo under `dist/ObjectiveKTableLab.app` is local build output, not a
signed-for-distribution or notarized release.

## Start With A Native Application

1. [Live field tutorial](../tutorial/macos/README.md): read edits through an
   ordinary Krypton function without requiring Return.
2. [Table/filter source](../examples/objk/table_filter.ks): retain a data source,
   filter native arrays, inspect selection and handle selected keys.
3. [AppKit event API](objk_appkit_events_macos.md): exact signatures, ownership,
   error results, threading and platform scope.
4. [Other examples](../examples/objk/README.md): models, controls and graphics.

Use system controls and the main thread. Keep callbacks short; do not wait for
a subprocess from a UI callback. The existing process-capture helpers are
synchronous, not a background-job framework.

### Callback Contracts

| Registration | Handler parameters | Result |
| --- | --- | --- |
| `okClick(control,funcptr(handler))` | `(self,command,sender)` | Ignored native action result. |
| `okOnKeyDown(table,funcptr(handler))` | `(table,event)` | Nonzero consumes; 0 preserves native table handling. |
| `okFieldOnChange(field,funcptr(handler))` | `(field)` | Ignored; read current text with `okText(field)`. |
| `okWindowShouldClose(win,funcptr(handler))` | `(win)` | Integer 1 permits user close; 0 vetoes. Direct `close` bypasses this. |
| `okWindowOnClose(win,funcptr(handler))` | `(win)` | Ignored; close notification, not a veto or Quit hook. |
| `okAppOnOpenFile(app,funcptr(handler))` | `(app,path)` | Integer 1 handled, 0 rejected; path is borrowed text. |
| `okAppOnReopen(app,funcptr(handler))` | `(app,hasVisibleWindows)` | Integer 1 permits native default behavior; 0 fully handled. |
| K-owned method registration/declaration | `(runtime,self,...)` | Must satisfy the declared runtime contract. |

These signatures are not interchangeable. `funcptr` points to a named function;
it does not capture locals or create a closure. Native callback arguments are
borrowed. The code pointer must remain valid and its signature must match.
Passing 0 detaches one handler. Lifecycle hooks share one retained proxy per
owner and release it when the last paired hook is removed. Foreign delegates are
not replaced; callbacks may safely detach themselves. A foreign field delegate is
not overwritten. Programmatic `okSetText` is not a user-edit notification.

Native table selections are NSIndexSet handles, not comma/newline lists.
`okSelection` returns an immutable, autoreleased snapshot. Use
`okSelectionNew`/`okSelectionAdd` for a mutable builder. See the API guide before
retaining values beyond an autorelease pool or adding references that can cycle.

## K-Owned Object Declarations

Compiler declarations lower to the K-owned runtime. For example:

```krypton
objk object Counter {
    method value() -> int = counterValue
}

func counterValue(runtime, self) {
    emit okKGet(runtime, self, "value")
}

just run {
    let counter = okKNew(__objkRuntime, Counter)
    doKSet(__objkRuntime, counter, "value", 42)
    print(okKSend(__objkRuntime, counter, "value"))
    doKRelease(__objkRuntime, counter)
}
```

`objk` declarations auto-import their runtime. They currently belong in the
executable entry source; putting reusable object/protocol declarations into
imported modules is still open. Ordinary imported functions and module globals
are supported within the current import walker's limits. See the
[runtime guide](objk_runtime_macos.md) and [implementation spec](../spec.md) for
inheritance, protocols, runtime type checks, arena lifetime and cleanup.

Runnable source: [owned-model tutorial](../tutorial/macos/02_owned_model.k).
Build it with the same development driver; running it prints `42` and releases
the model. This model has no native window or Apple object-framework dependency.

Use `-> do` for an explicit no-result type in new declarations, not `void`.
Callbacks with ignored results may remain unannotated. Do not assume runtime
type checks are compiler type checking or automatic reference counting.

## Rules For Contributors And AI Tools

- Confirm an API in its module or current reference before using its name.
  A handoff's requested signature is a proposal, not an implemented function.
- Keep application code Krypton. Do not add `.m`/`.mm`, generated C, or a
  Clang-based fallback to paper over missing adapter support.
- Do not stringify native pointers, swap callback ABIs, or pass selector
  pointers to `msg`, which takes a selector-name string.
- Do not equate the framework-free object core with a statically linked GUI.
- Keep `exec` (stdout capture) and `shellRun` (inherited output/status text)
  contracts distinct. Do not change `shellRun` to satisfy an outdated test.
- Do not claim imported declarations, drag/drop, async jobs, full struct-return
  support, automatic lifetime safety, or platform parity without implementation
  and verification. Keep source, installed tools and published releases distinct.
- Keywords such as `callback`, `process`, `go`, `fn` and `default` cannot be
  binding or parameter names. The development frontend now rejects them rather
  than silently loading empty text. Use names such as `handlerBox` or `fallback`.

## Verification And Open Work

```sh
./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_objk_runtime_macos.ks
```

The focused macOS Objective-K gate includes adapter and
K-owned runtime regressions. The table demo's real typing, filter clearing,
Down, Return, Escape, single/double clicks and retained-window close/reopen were
checked through native UI. That is not a full
compiler-suite, accessibility, IME, or cross-platform certification.
New column/action/image/menu helpers have native regressions. Frame restoration
was checked with desktop access; without a display that case explicitly skips.
Pending native class names are now reused before registration, with a diagnostic
for conflicting parents. Native class creation remains main-thread-only.
Lifecycle tests cover native close veto/notifications, independent delegates and
safe self-detachment. App open-file/reopen tests invoke the native delegate
methods; this does not prove Finder associations or bundle document routing.

The [Cortex tracker](objk_cortex_followup.md) contains the AppKit tasks and
Freebuff's updated compiler findings. The [Synapse tracker](objk_synapse_followup.md)
contains process/bundling/module work. The handoffs remain open; this guide is
not a claim that all 42 API requests are finished.

The frontend also diagnoses bare `void`, unmatched/unclosed delimiters and
reserved identifiers before scanners run. Valid function-only modules still
emit library IR and import normally. The macOS driver rejects those modules only
when asked for an executable without `just run`/`go run`. Its separate
`scripts/check_macos_driver.ks` gate checks stderr/IR separation, child exit
statuses, output-directory errors and preservation of existing output on failure.
Diagnostics identify the input or imported file; full line/excerpt/debug mapping
remains open. Native `jxt` function declarations are not compiled as bodies.
The isolated rebuilt toolchain also passed 16 driver-contract checks and the
broader native suite (71 passed, 0 failed, 8 platform skips). Two successive
frontend self-host generations are byte-identical. These are development tests,
not installer, signing, notarization or store-submission validation.
Tutorial compilation: 33 passed, with three explicitly excluded native gaps
(closures, Win32 HTTP internals and browser-only lesson APIs); see the
[tutorial scope](../tutorial/README.md). Do not report a clean all-lessons gate.
