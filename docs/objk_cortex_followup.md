# Cortex macOS Objective-K Follow-Up

Source: cortex-mac `KRYPTON-LANG-HANDOFF.md`, measured against installed 2.4.8.
Keep this work alongside [Synapse follow-up](objk_synapse_followup.md), not
instead of it. This tracker describes development sources, not a shipped update.

## Next AppKit Work

First macOS slice is implemented and verified; remaining work stays queued.
Preserve the correctness gates and both handoffs.

- [x] First slice: table selection, keyboard callbacks, and live filtering.
- [ ] Complete columns, double-click, and native drag/drop behavior.
- [ ] Strengthen method-signature checks, callback ownership, and cleanup.
- [ ] Add close/open-file hooks, session restoration, and frame persistence.
- [ ] Finish live text events, menu state, image views, and confirmation sheets.
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

- [ ] P0-10: reproduce and diagnose frontend crashing on
  `func main() void { print("main") }`. Check malformed return syntax separately
  from valid function-only modules and executable entry handling. Do not reject
  valid libraries merely because they have no `just run` block.
- [ ] P0-7 residual: repeated allocation of the same class name before either
  class is registered. Registered-name lookup alone does not cover this case;
  add pending-name tracking only after reproducing and testing the native path.
- [ ] Diagnostics: file, source line, containing function and short source
  excerpt for compiler errors; optional address-to-source mapping under a
  future `--debug` for runtime failures. No verbose tracing by default.
- [ ] Compiler identifier collision: local `callback` lowers to empty text
  instead of loading the variable. This slice uses `handlerBox`; add a compiler
  regression and fix name resolution rather than treating the workaround as done.

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

- D1 public multi-column setup.
- D2 column widths, row heights, reload.
- D3 native selection snapshots/builders, mutation and scrolling added for
  macOS. See the API guide for index-set ownership and selection-policy limits.
- D4 click/double-click dispatch (default callback isolation fixed separately).
- D5 macOS table key hook added; unconsumed events retain native navigation.
  Arbitrary foreign NSTableView instances are not silently subclassed.
- D6 drag-source callbacks and pasteboard representations.
- D7 drop validation/acceptance, row targeting, copy/move policy.

### E: Controls

- E1 macOS live field-change delegates added, with rebinding/detachment and
  refusal to overwrite another delegate.
- E2 segmented-control wrappers added over existing Choc primitives. Native
  state and action routing are covered by the callback regression test.
- E3 image-view creation and file loading.
- E4 menu check/enabled state.
- E5 scrollable text alerts and confirmation results.

### F: Lifecycle

- F1 window frame persistence.
- F2 close callbacks and session-save ordering.
- F3 application open-file delegates and bundle document declarations.
- F4 existing-instance activation and reopen behavior.

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

Current development verification: **93 checks pass** in the macOS Objective-K
runtime checker, including unknown-call/funcptr rejection, format imports,
callback isolation/rebinding, duplicate classes, segmented-control state, table
selection/key dispatch and live field notifications. The table example's actual
typing, empty-filter recovery, arrow fallback, Return and Escape were verified.
Strict symbol checking may expose other dormant library defects; audit imports
before release rather than restoring silent unresolved calls.

Run `kcc -r scripts/check_objk_runtime_macos.ks` with the development
`KRYPTON_ROOT`. Run Cortex's `krypton/langcheck.sh` through its `KCC` override
as a secondary measured tracker, accounting for the contract corrections above.
Do not claim drag/drop or the full Cortex app is verified from unit tests alone.

Historical run of the original unmodified Cortex suite: **7 passed, 8 failed**. The
remaining count includes the incompatible shellRun assertion and two mismatched
import fixtures, alongside real unresolved padding, sorting, splitting and
output-path defects. Do not report this as 15/0. Missing-import diagnostics
should also be hardened so a bad filename is reported before symbol resolution.
