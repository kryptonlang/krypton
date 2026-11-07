# Synapse Objective-K Handoff Follow-Up

Source report: Synapse `docs/objk-handoff.md`, reproduced against Krypton
2.4.8. This is source work for the next release, not an installed-tool update.

## First Fix Set

- `ossystemk` returns `shellRun` status instead of hardcoding success.
- Builtin documentation distinguishes captured stdout (`exec`) from inherited
  output plus exit-code text (`shellRun`). Neither builtin contract changed.
- Mach-O foreign-import and emitted-binary diagnostics end in newlines.
- `nsToStr` converts an object's description to UTF-8 and handles nil.
- `newPool` uses a class-name literal, avoiding an unresolved header constant
  when `k:objc` is reached through another imported module.
- `k:objk_process_macos` adds literal argv execution and combined text capture
  using Foundation's NSTask. It needs no shell for argv calls, no generated
  C/Objective-C, and no new pointer-arithmetic builtin. The shell variant is
  explicit. This is not a portable or streaming `k:proc` replacement.
- Runtime guide and spec distinguish the framework-free K-owned core from
  GUI adapters linked to Apple's frameworks and libobjc.

Regression entry point: `kcc -r scripts/check_objk_runtime_macos.ks` from
the Krypton root with `KRYPTON_ROOT` pointing at this checkout. New tests cover
status propagation, object text conversion, transitive autorelease-pool setup,
argv spaces/metacharacters/empty arguments, combined output, nonzero and signal
exits, launch failure, invalid UTF-8, and output beyond pipe capacity.

Verified on macOS arm64: the full runtime checker passes with the rebuilt
Mach-O backend, and foreign-import diagnostics are separated from the emitted
binary diagnostic by a newline. Published installers remain unchanged.

The development checkout now includes rebuilt macOS frontend, frontend seed and
driver binaries. Successive native frontend self-host builds are byte-identical;
109 focused checks, 19 driver-contract checks and the broader native suite
(71 passed / 0 failed / 8 platform skips) pass. Synapse controller compilation
was checked, not a full browser UI migration or runtime/deployment test. Local
2.4.9 macOS pkg/tar candidates are signed, notarized and stapled; installation
and Gatekeeper checks pass. Publication remains separate.

## Still Open

1. General app bundling is restored in `scripts/build-objk-app.ks`, with explicit
   output/identifier/version/icon/compiler settings, plist escaping and checked
   builds. It preserves kweb's embedded toolchain. Signing/notarization remain
   separate release steps; use the bundled helper, not a hand-written C build.
2. Imported Objective-K declarations and shared declaration initialization.
   Imported modules currently need direct runtime APIs, as documented.
3. Native pointer arithmetic and raw POSIX argv/wait support on macOS. The new
   Foundation adapter bypasses this gap; it does not close backend parity.
4. Asynchronous process capture, timeout/cancellation, bounded/streaming output,
   binary output, and launch-error detail. Current helper is synchronous and
   buffers UTF-8 output; do not call it for unbounded services or on a GUI main
   thread that must remain responsive.
5. Synapse migration and verification. Its workarounds remain unchanged until
   its process controller deliberately adopts and tests these APIs. An installed
   2.4.8 compiler alone does not contain the new stdlib source.

Windows process implementation and the existing `exec`/`shellRun` ABI are
unchanged. Cross-platform testing is still required before release.
