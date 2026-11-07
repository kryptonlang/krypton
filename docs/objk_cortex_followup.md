# Cortex macOS Objective-K Follow-Up

Source: cortex-mac `KRYPTON-LANG-HANDOFF.md`, measured against installed 2.4.8.
Keep this work alongside [Synapse follow-up](objk_synapse_followup.md), not
instead of it. This tracker describes development sources, not a shipped update.

## Next AppKit Work

First macOS slice is implemented and verified; remaining work stays queued.
Preserve the correctness gates and both handoffs.

- [x] First slice: table selection, keyboard callbacks, and live filtering.
- [x] Columns, row geometry, independent single/double target/action handlers.
- [x] Real single/double-click gesture verification in the two-column demo.
- [ ] Native drag/drop behavior.
- [ ] Strengthen method-signature checks, callback ownership, and cleanup.
- [x] Add close veto/notification and app open-file/reopen hooks; explicit frames.
- [ ] Session restoration, termination hooks, and Finder document routing.
- [x] Live text events, menu check/enabled state and image views/file loading.
- [ ] Confirmation sheets and scrollable alerts.
- [ ] Add cancellable background processes and main-thread progress delivery.
- [x] First-slice runnable example, automated checks, API/lifetime docs, and
  native UI verification. Apply the same requirements to later slices.
- [ ] Keep platform adapters distinct and document untested platform behavior.

API guide: [macOS table and field events](objk_appkit_events_macos.md).

## Freebuff Handoff Update

Reread the external handoff updated against `ed662321`. Its current baseline is
**8 pass / 7 fail** after correcting module fixtures. It confirms unknown-call,
default callback, duplicate registered-class and segmented-control fixes;
module-global import failure is no longer reproducible. Earlier results below
are historical, not the current external baseline.

- [x] P0-10: bare `void` gets a filename-bearing syntax error before scanners;
  malformed delimiters are rejected and block scans are bounded. Valid library
  IR/imports still work; only macOS executable builds require an entry block.
- [x] P0-7 residual: pending-name registry reuses a native class before
  registration, rejects conflicting parents/handles, and clears on registration.
  Native regression covers repeated allocation before registration.
- [ ] Diagnostics: file, source line, containing function and short source
  excerpt for compiler errors; optional address-to-source mapping under a
  future `--debug` for runtime failures. No verbose tracing by default.
- [x] Compiler identifier collision: reserved names such as `callback` and
  `process` are rejected in bindings/parameters, not silently lowered to empty
  text. This is a diagnostic fix, not support for keyword identifiers. Existing
  stdlib fallback parameters now use `fallback` instead of reserved `default`.
- [x] macOS driver output failures/streams: missing directories are diagnosed
  on stderr; staging preserves old output after frontend/backend failures.
  Library IR remains valid and `-r`/`-e` propagate child streams/status.

The handoff also corrects lifecycle expectations: activation of an existing
live window already works through AppKit. Recreating a closed window and
second-process policy remain separate, unverified requirements.

## Contract Corrections

- `shellRun` returns exit-code text and inherits output. Changing it to return
  stdout would break builds and existing applications. Use `exec` for stdout;
  `okRunCaptured`/`okRunArgvCaptured` provide combined output plus status.
  Separate streams, cwd, and timeouts remain open. Cortex's check expecting
  `shellRun("echo hi") == "hi"` must be revised before using 15/0 as a gate.
- Module-global import support already has a passing regression. Reproduce the
  exact Cortex module shape before deciding it needs another implementation.
- The supplied shell suite writes `modstate.ks` and `shadowmod.ks`, but imports
  `modstate.k` and `shadowmod.k`. Those fixtures do not test existing modules;
  fix their extensions before judging module state or name-shadowing results.
- Point/rectangle return-component helpers already exist. A general struct/out
  parameter contract is still missing; do not equate that with no return support.
- `len(splitStr(...)) == 3` presupposes a collection representation. Establish
  lossless list semantics, including empty fields and separator-containing
  values, before adopting that assertion. Legacy list indexing must remain valid.
- The handoff calls its feature section 42 elements; its A-H tables contain
  6+9+3+7+5+4+3+5 = 42 rows, including repeated record/global-state requests.

## Correctness Gates

1. Unknown direct calls and unknown `funcptr` targets: fail codegen with symbol
   and containing function, rather than branching to a missing address. Source
   line diagnostics, suggestions, and frontend-only checking remain open.
2. Padding builtin correctness, arity, and module/builtin collision rules.
3. Sorting and lossless text splitting contracts.
4. Callback isolation: default registrations need unique keys and retained
   targets. Regression directly invokes three controls' action targets and
   verifies rebinding does not change other controls.
5. Duplicate class creation/registration and method-add failure: return existing
   registered classes, check nil and runtime results, report named diagnostics.
6. Exact module-state repro, output-path failure streams, and compiler-name
   collision documentation.

Strict call resolution also exposed `formatHex` calling a nonexistent `hex`
function. It now converts in Krypton, with regression coverage for the existing
format helpers and hexadecimal output.

Additional probe found while testing: native unary-negative values passed
through numeric/string conversion can crash (for example `formatHex(-15,4)`).
The current hex helper supports nonnegative inputs only. Investigate NEG's raw
signed-64 result versus the guarded-integer representation before changing it;
graphics ABI paths also consume signed native values and must not regress.

## API Backlog

Entries remain pending unless explicitly stated; this is not a completion list.

### A: Text And Records

- A1 `splitStr(text, separator)` with lossless field semantics.
- A2 `splitLines(text)` and trailing-line policy.
- A3 `joinStr(parts, separator)` / compatible `joinLines`.
- A4 `sortLines` and field/key sorting without subprocesses.
- A5 tuples/records with explicit representation and ABI.
- A6 correct padding and builtin/module name resolution.

### B: Filesystem

- B1 native file metadata with numeric size/time and documented record encoding.
- B2 directory entries, ordering, error handling, and escaping.
- B3 recursive directory size with symlink/cycle policy.
- B4 file hashing: SHA-256 and MD5 compatibility use.
- B5 system Trash integration.
- B6 mounted volumes and capacity.
- B7 volume eject with errors.
- B8 open-with and reveal-in-Finder.
- B9 symlink detection/target and executable checks.

### C: Processes

- C1 separate stdout/stderr, cwd, timeout and literal argv. Existing macOS
  capture covers combined UTF-8 output/status only; it is synchronous.
- C2 line-oriented process results using A's collection contract.
- C3 preserve/document `exec` versus `shellRun`; documentation already fixed.

### D: Tables

- D1 `okColumn` adds/updates named columns, retaining the existing `c0` default.
- D2 column widths, row heights and reload implemented for macOS.
- D3 native selection snapshots/builders, mutation and scrolling added for
  macOS. See the API guide for index-set ownership and selection-policy limits.
- D4 independent typed table single/double actions added. Native target/action
  routing and real demo gestures are tested; drag/drop is separate.
- D5 macOS table key hook added; unconsumed events retain native navigation.
  Arbitrary foreign NSTableView instances are not silently subclassed.
- D6 drag-source callbacks and pasteboard representations.
- D7 drop validation/acceptance, row targeting, copy/move policy.

### E: Controls

- E1 macOS live field-change delegates added, with rebinding/detachment and
  refusal to overwrite another delegate.
- E2 segmented-control wrappers added over existing Choc primitives. Native
  state and action routing are covered by the callback regression test.
- E3 image-view creation/file loading added; failures preserve the prior image.
- E4 menu check/enabled state added; enabling disables whole-menu autovalidation.
- E5 scrollable text alerts and confirmation results.

### F: Lifecycle

- F1 explicit frame save/restore added and desktop-tested. No lifecycle delegate
  is installed; applications choose when to save. No-display requests fail.
- F2 close veto/notification hooks added; Quit/session-save ordering remains
  application work, not automatic termination handling.
- F3 application open-file hook added; bundle document declarations, sandbox
  access and actual Finder routing remain unverified.
- F4 app reopen hook added; the demo retains/reuses its closed window. This is
  not automatic window recreation or second-process coordination.

### G: Language And FFI

- G1 general native structure returns and checked out-parameters.
- G2 records/tuples (same work as A5).
- G3 imported module state and declarations (also Synapse's open request).

### H: Tooling

- H1 unknown identifier errors, source locations and suggestions.
- H2 frontend check-only mode, without emitting binaries.
- H3 stdlib/function discovery and documentation lookup.
- H4 reusable app bundling, also tracked for Synapse.
- H5 debug diagnostics for invalid object/IMP usage; cannot make arbitrary raw
  pointers safe without a broader FFI contract.

Additional tooling: document Apple's unrelated `/usr/bin/kcc`; avoid replacing
system files. Test runner and formatter need separate designs. Keep existing
working `format`, `sh`, conversion, path, AppKit, and signed-binary behavior.

## Verification

Current development verification: **109 checks pass** in the macOS Objective-K
runtime checker, including unknown-call/funcptr rejection, format imports,
callback isolation/rebinding, duplicate classes, segmented-control state, table
selection/key dispatch and live field notifications. The table example's actual
typing, empty-filter recovery, arrow fallback, Return and Escape were verified.
Native tests additionally cover column/action/menu/image helpers and pending
class registration. Frame save/restore was verified with desktop access; the
test explicitly skips that part when no display is visible.
The lifecycle regression adds native close veto/notification tests, foreign
delegate refusal, per-window isolation, rebinding and self-detachment; application
open-file/reopen selectors are exercised directly, not through Finder.
The native demo's single/double clicks and close/reopen cycle were also checked;
the filtered row survived closing and the reopen callback updated the status.
Strict symbol checking may expose other dormant library defects; audit imports
before release rather than restoring silent unresolved calls.

Run `kcc -r scripts/check_objk_runtime_macos.ks` with the development
`KRYPTON_ROOT`. Run Cortex's `krypton/langcheck.sh` through its `KCC` override
as a secondary measured tracker, accounting for the contract corrections above.
Do not claim drag/drop or the full Cortex app is verified from unit tests alone.

Rebuilt macOS toolchain: byte-identical frontend/backend self-host fixpoints, 19 driver
contract checks, and broader native suite 71 passed / 0 failed / 8 platform
skips. kweb GUI, Synapse controller, Stem and Brain compile probes passed; those
are not full UI or deployment tests. Stem/Brain's local reserved `go` loop names
were renamed to `scanning`. Tutorial sweep still exposes unsupported macOS
closures, Win32-only HTTP internals, and browser-only `fetch`/`nowSec`; do not
claim every lesson works natively. The local 2.4.9 macOS pkg/tar candidates are
signed, notarized and stapled; temporary installs and Gatekeeper checks pass.
Publication, Homebrew and website updates remain separate.

Cortex's current source compiles against the candidate and its 38-check
`--selftest` passes from its `krypton/` directory with the existing PXBridge
bundle. No Objective-C source was compiled for that check. This does not remove
Cortex's separate bridge dependency or certify its full interactive UI.
The secondary language tracker is 11 passed / 4 failed: sorting, newline sort
contract mismatch, missing lossless splitting, and an incompatible shellRun
capture assertion. `shellRun` intentionally returns status; `exec` captures.
Raw builder-text collection still fails; the new explicit snapshot regression
passes. See [Cortex SDK notes](release-staging/cortex-macos-objk.md).

Historical run of the original unmodified Cortex suite: **7 passed, 8 failed**. The
remaining count includes the incompatible shellRun assertion and two mismatched
import fixtures, alongside then-unresolved padding, sorting, splitting and
output-path defects. Do not report this as 15/0. Missing-import diagnostics
should also be hardened so a bad filename is reported before symbol resolution.
