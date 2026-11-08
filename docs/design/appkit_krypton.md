# Krypton-Owned UI Toolkit

Planning baseline: 2026-11-08. This is not a shipped AppKit replacement.
Objective-K already replaces Objective-C source/compilation while calling
Apple's libobjc, Foundation and AppKit. Keep that working adapter during any
independent toolkit implementation. No C, Objective-C, generated C/Objective-C,
or Clang build step is part of the proposed implementation.

## Orbit Incident And Required Guardrails

Reported environment: macOS 27.3 (26C5035r), arm64, Krypton 2.4.9 and the
development checkout. Orbit uses `k:cocoa`/`k:objc`, a manual event pump and
per-frame NSAutoreleasePool scopes.

The supplied handoff reports an earlier associated-object crash and a later
`NSInvalidArgumentException` on `__NSAppKitThreadSpecificData` with garbage
selector bytes. These are distinct failure modes, not evidence by themselves
of a broken selector-registration implementation.

The latter crash was reproduced with the current Orbit frontend, an isolated
temporary app/data directory and a Krypton-written local engine stub. No torrent
engine or network was needed. Native desktop access was required: a sandboxed
run did not reproduce the same behavior. Its smoke test contained two calls:

```krypton
msgRectHeight(msg(get("tablescroll"), "frame"))
```

There are two errors: `msg(...,"frame")` discards the NSRect result in floating
registers and treats unspecified x0 as a handle, then `msgRectHeight` is called
without its required selector-name argument. Disassembly of the reproduced
binary maps the throwing return address to the rectangle-height helper and its
caller to this smoke-test expression. Correct both sites to:

```krypton
msgRectHeight(get("tablescroll"), "frame")
```

The compiler now rejects missing/extra arguments to defined Krypton functions,
including imported helpers and forward calls, before machine-code emission.
This is a development change after released 2.4.9. It does not infer native
method signatures from selector strings or validate arbitrary function pointers.

Relevant local evidence was `Orbit-2026-11-08-025622.ips` in the user's
DiagnosticReports folder. A separate later report, `Orbit-2026-11-08-170735.ips`,
names `NSTableView setTextColor:`; do not conflate it with selector corruption.
Original Orbit popup/build edits must be preserved; only the two rectangle calls
belong to this correction. Do not publish full crash logs containing user paths.

Other contracts to retain:

- `sel(name)` accepts live, NUL-terminated UTF-8, including computed names.
  `msg*` accepts a name, not a SEL handle. Registration is synchronous; a builder
  interior pointer cannot be kept across mutation/collection before registration.
- Associated values under retain/copy policies must be native objects or nil.
  Wrap Krypton text with `nsString`; do not retain a raw Krypton allocation as id.
- `nsString` is autoreleased. Copy borrowed UTF-8 or retain the owning native
  object before draining a pool. No blanket retain/copy can repair a wrong ABI.
- Keep AppKit on the main thread, retain callback state explicitly and balance
  frame pools. Snapshot input before handing it to longer-lived toolkit state.

Regression entry points: `tests/macos/test_objk_selector_pool.k`,
`tests/macos/test_call_arity.k`, the four call-arity fixtures, and
`scripts/check_objk_runtime_macos.ks --gui`. Desktop tests do not establish
Windows/Linux parity, interactive accessibility or every native method ABI.

Validation on this machine: the corrected Orbit source passed the isolated
stub-backed smoke test when compiled against both installed 2.4.9 and the
development root. Its existing development app bundle was rebuilt from the
corrected frontend and its ad-hoc signature refreshed/verified; the bundled
engine/resources were unchanged. The actual torrent engine/network was not
tested. The 100-frame selector/pool regression passed with both toolchains and
desktop AppKit access. A correctly formed window/pool/event-pump probe did not
reproduce the exception. Native compiler tests passed 71/0 with 8 documented
platform skips, and the driver contract gate passed. The full Objective-K gate
with `--gui` passed; the frame-persistence, counter and Focus smoke tests were
also rerun with desktop access and passed. These are automated integration
checks, not manual typing/IME/accessibility certification. No installed
compiler, release seed or published release artifact was replaced.

## Metadata To Collect

Use public SDK declarations/documentation and runtime introspection as interface
evidence, not Apple's implementation. Record source URL/path, SDK/OS version,
architecture, collection method and redistribution terms for every dataset.
Review those terms before tracking SDK-derived bulk output. Do not copy Apple's
APSL runtime implementation into Apache-2.0 code without addressing its license.

For each API record class/protocol, superclass, class-vs-instance method,
selector, exact argument and return types, native encoding, scalar widths,
struct size/alignment/fields, register ABI, property accessors, enum values,
ownership, nullability, delegate/block lifetime, main-thread requirements,
availability/deprecation and a behavior-test reference. Mark unknown facts
explicitly. Runtime encodings alone omit ownership, availability and other SDK
semantics. Unsupported signatures must produce diagnostics, not guessed calls.

Native encoding seed: `@` object, `#` class, `:` selector, `i`/`I` signed/unsigned
int, `q`/`Q` signed/unsigned 64-bit integer, `d` double, `^v` untyped pointer.
These describe native ABI categories, not K-owned object or arena text types.
Resolve actual SDK types: window style masks use `NSUInteger`, not a generic
32-bit `int`; `CGFloat` is `double` on macOS arm64. Capture return type, hidden
receiver/selector, qualifiers, Boolean encoding and aggregate layout. An `@`
encoding alone does not identify the expected object class. Use public SDK
declarations plus [Apple's encoding reference](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html).

Start with NSApplication, NSWindow, NSView, NSButton, NSTextField, NSMenu,
NSEvent and NSResponder; then NSScrollView, NSTableView and text/accessibility
protocols. Test inheritance and actual receiver support, not just global names.

## Implementation Sequence

1. Harden the existing bridge: arity checks, typed ABI catalog, borrowed/owned
   lifetime rules, negative tests and diagnostics naming the caller/API.
2. Define K-owned view trees, geometry, layout, theme tokens, state and event
   values with framework-free tests. Keep native pointers outside arena handles.
3. Use a small macOS adapter for windows, displays, event intake, drawing and
   system services. Implement K-owned labels/buttons/layout first, with explicit
   focus, hit testing, keyboard traversal and native system appearance changes.
4. Add editable text with selection, clipboard, undo, Unicode shaping and IME;
   scrolling, menus, tables, drag/drop and accessibility follow as explicit
   projects. Retain native controls where those contracts are not ready.
5. Move one small application onto the toolkit behind an opt-in backend. Require
   interaction, lifecycle, leak/lifetime, HiDPI, appearance and accessibility
   checks before expanding use. Keep the existing AppKit backend as a fallback.

AppKit metadata accelerates bindings and specifications, not independent
implementations. Full replacement has no promised date. Apple's window system
and other public OS services remain dependencies; no private WindowServer SPI.
Portable model/layout APIs belong in shared K modules; native integration keeps
an explicit macOS adapter name. Other platforms require their own validation.

## Public References

- [AppKit scope](https://developer.apple.com/documentation/appkit)
- [NSView frame returns NSRect](https://developer.apple.com/documentation/appkit/nsview/frame)
- [Selector conversion/registration](https://developer.apple.com/documentation/foundation/nsselectorfromstring(_:))
- [Associated objects](https://developer.apple.com/documentation/objectivec/objc_setassociatedobject(_:_:_:_:))
- [AppKit accessibility](https://developer.apple.com/documentation/appkit/accessibility-for-appkit)
