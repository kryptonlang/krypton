# Krypton Implementation Spec

This is the index and integration contract for the current source checkout,
not a release announcement. Language syntax: [EBNF](grammar/krypton.ebnf) and
[grammar notes](docs/spec/grammar.md). References:
[functions](docs/spec/functions.md), [types](docs/spec/types.md),
[imports](docs/imports.md), [GUI](docs/spec/gui.md).

## Objective-K Scope

This spec covers three macOS Objective-K stages: compiler support and K-owned
class/message core; owned/weak fields and cleanup; then storage reuse with fresh
IDs. It excludes Windows merge and deployment work. Native verification is
macOS arm64 only. Checkout capabilities do not establish a published version.
The macOS AppKit event adapter is specified separately from the K-owned core.
For a human/AI entry point, see [Objective-K: start here](docs/objective_k.md).

## Language And Compiler Contract

`.k` and `.ks` use the same compiler and syntax. KryptScript can import
Objective-K modules; it is not a separate Objective-K interpreter. The driver
can wrap script statements in an entry block. Explicit `just run` remains valid.

The compiler accepts top-level `objk protocol` and `objk object` declarations
and lowers them to K-owned runtime setup before entry work. It auto-imports
`k:objk_runtime_macos`. Existing `class`/`struct`/`type` declarations are not
K-owned runtime classes. Direct runtime calls remain supported.

This first declaration stage supports protocol/object inheritance, multiple
protocol conformances per object declaration (`conforms A, B`), callback-backed
methods, and 0..2 typed user arguments. Declared conformances build witness
tables per (declaring class, protocol) pair at registration. Generated entry
locals expose `__objkRuntime` and each declaration name. Types lower to runtime
contracts: `int`/`integer`, `text`, a previously
declared object/protocol name, or unconstrained `any`/`do`. Method callbacks
receive `(runtime, self)` before user arguments. Inline method bodies, fields,
ownership syntax, and compile-time message checks remain planned. Declarations
currently belong in executable entry source;
imported modules should use direct runtime APIs.

Use `-> do` for an explicit no-result contract. Do not add `void` declarations
to new APIs. The unannotated cleanup callbacks in the prototype return an
ignored value; that is not a new return-type rule.

### Imported Globals

`compiler/compile.k` collects module-scope `let`/`const` initializers from files
found by the existing import walker. Their initialization IR is prepended to
executable `__main__` in dependency-first traversal order, before entry work.
Imported functions can read and mutate module globals; local declarations and
parameters continue to shadow them.

Limits: the current walker handles its existing one dependency layer, not an
arbitrary transitive graph. This change does not supply namespaces, entryless
DLL initialization, or imported floating-point type propagation. Do not assume
cyclic imports have defined initialization semantics.

### Native Indirect Calls On macOS arm64

`callPtr(pointer, arg0, ...)` accepts zero through eight native Krypton
arguments. The pointer is not counted among those arguments. Object methods
pass `(runtime, self)` plus zero, one, or two user arguments; cleanup passes
only `(runtime, self)`.

The Mach-O emitter preserves native boxed values and returns. Generated
`BUILTIN callPtr` IR requires one through nine total operands. Missing pointer
or excess arguments produce `callPtr needs a pointer and 0..8 arguments`.
Null pointers trap before branching; the checker expects SIGTRAP/exit 133.
Function signature correctness remains the caller's responsibility. This is
not a generic foreign ABI, closure-capture ABI, or compiler-checked method call.
Handwritten IR must not bypass the builtin validation with an unrelated CALL.

## K-Owned Objective-K On macOS

Implementation: [stdlib/objk_runtime_macos.k](stdlib/objk_runtime_macos.k).
Usage and lifetime examples: [runtime guide](docs/objk_runtime_macos.md).
No Cocoa, Foundation, AppKit, UIKit, or libobjc imports belong to this core.
Existing GUI adapters still use native Apple frameworks. Choc/OKUI changes
the app-facing API; it does not yet replace Apple's windowing implementation.

GUI apps using `k:okui` still link to `libobjc`, Foundation, and AppKit; the
K-owned core's no-framework contract does not apply to those apps. Pure-Krypton
source does not mean static framework linkage. See the runtime guide's
[native GUI boundary](docs/objk_runtime_macos.md#native-gui-boundary).

`k:objk_process_macos` provides literal argv execution and combined text-output
capture through Foundation without generating C/Objective-C or using a shell
for the argv path. This is a macOS adapter, not a portable replacement for
`k:proc`. See [process capture](docs/objk_runtime_macos.md#macos-process-capture).

### Public API

| API | Contract |
| --- | --- |
| `okKRuntime(capacity)` | Rooted arena, 64..1048576 bytes; small capacities may not fit records. |
| `okKText(runtime, text)` / `okKTextValue` | Copy text into arena / return text value. |
| `okKRetainText` / `doKReleaseText` / `okKTextRefCount` | Manage caller-owned arena text references. |
| `okKClass(runtime, name, parent)` | Nonempty name; parent 0 or registered class. |
| `okKClassName` | Retrieve stored class name. |
| `okKMethod(runtime, klass, name, arity, pointer)` | Before sealing; unique nonempty name, nonnull pointer, arity 0..2. |
| `okKObjectMethod(runtime, klass, name, arity, pointer, firstClass, secondClass, resultClass)` | Runtime object-class constraints; 0 means unconstrained. |
| `okKTypedMethod(runtime, klass, name, arity, pointer, firstType, secondType, resultType)` | Runtime integer, text, class, or protocol constraints. |
| `okKTypeInteger()` / `okKTypeText()` | Type tokens for typed method signatures. |
| `doKCleanup(runtime, klass, pointer)` | Before sealing; one nonnull cleanup callback per class. |
| `doKRegister(runtime, klass)` | Seal class; instance creation then permitted. |
| `okKNew(runtime, klass)` | Live instance with one independent reference. |
| `okKObjectClass` / `okKIsA` | Dynamic class / ancestry check. |
| `okKResponds` | Check method lookup on a readable object. |
| `okKSend` / `okKSend1` / `okKSend2` | Dispatch with matching user-argument count. |
| `okKSuper(runtime, object, definingClass, name)` | Zero-user-argument dispatch from defining class's parent. |
| `doKSet(runtime, object, name, value)` | Borrowed integer/arena ID, range -1000000000..1000000000. |
| `doKOwn(runtime, object, name, child)` | Retain new child before replacement; release previous owned child; 0 clears. |
| `doKWeak(runtime, object, name, target)` | No retain/release; read as 0 once target starts releasing. |
| `doKText(runtime, object, name, text)` | Own arena text; retain replacement, release old value; 0 clears. |
| `okKHas` / `okKGet` | Distinguish absent field from stored 0 / read field. |
| `okKRetain` / `doKRelease` | Balanced manual ownership; reference-count overflow rejected. |
| `okKRefCount` | Count for object ID; 0 for previously issued ID whose storage was freed. |
| `okKProtocol(runtime, name, parent)` | Define named protocol; parent 0 or sealed protocol. |
| `doKRequireMethod(runtime, protocol, name, arity, firstClass, secondClass, resultClass)` | Add required method with exact object-class signature. |
| `doKRegisterProtocol(runtime, protocol)` | Seal protocol before adoption or use as parent. |
| `doKConform(runtime, klass, protocol)` | Explicit adoption before class sealing. |
| `okKConforms(runtime, object, protocol)` | Query inherited, declared conformance on readable object. |

Functions for allocation, lookup, raw record access, invocation, and freeing
are implementation helpers, not supported app APIs. In particular, do not call
`doKFree` directly or modify arena bytes. This prototype has no module-private
access enforcement; its checks are not a security boundary against buffer writes
or guessed valid IDs.

### Dispatch And Lifetime

Lookup starts at dynamic class and walks ancestors. Child methods override
matching names. Unknown methods, wrong arity, invalid IDs/kinds, and invalid
ownership operations fail with an `Objective-K:` diagnostic and exit 1.
`super` validates that its defining class belongs to the object's ancestry.

Borrowed fields do not manage references. Owned, weak, and text policies cannot be
overwritten by `doKSet` or converted to each other; a borrowed field can acquire
either policy. Clearing with the matching API preserves that policy. Getters
return borrowed values: retain before keeping an independent object reference.
Strong cycles are not collected. Break them explicitly or use weak back-links.

`okKText` returns one caller-owned reference. Balance it with
`doKReleaseText`; retain before keeping another independent reference.
`doKText` retains nonzero text before replacement, releases old text afterward,
and releases stored text during object teardown. Clearing preserves text policy.
Borrowed text stored with `doKSet` remains caller-managed and can become stale.

Final release sets references to 0 and state to releasing. It runs cleanup
most-derived first through all ancestors, then releases owned children and
reclaims private field names, field records, and the object record. Cleanup may
read fields, send read-only messages, run GC, and allocate other objects. It
cannot retain, release again, mutate, or install the releasing object in an
owned/weak field. Weak references to it already read 0. Hooks are automatic;
do not invoke parent cleanup manually. Field-release order is unspecified.
Failures are fail-fast, with no exception unwinding or transactional rollback.
All owner field records remain allocated until every owned-child release
callback completes, so child hooks can still read the releasing owner's fields.

### Object-Typed Methods

`okKTypedMethod` registers argument/result constraints alongside ordinary method
metadata. `okKObjectMethod` remains its compatible older name. Signature 0 means
unconstrained, not nullable. `okKTypeInteger()` accepts values inside the native
small-integer guard. `okKTypeText()` accepts live arena text IDs. A class handle
accepts readable instances of that class or subclasses. A sealed protocol handle
accepts readable, nominally conforming objects. Class/protocol constraints are
nonnullable: 0 is not an object ID. Absent argument positions must use 0.
Signature handles must identify classes/protocols; a class can reference itself
before sealing, and protocol requirement signatures can reference definitions
available in the same arena.

Dispatch checks arguments before calling and the result afterward. It does not
retain arguments/results or check native callback ABI. Legacy `okKMethod`
overrides copy inherited object constraints and must keep typed-parent arity.
Explicit typed overrides must match typed-parent constraints exactly; variance
is not implemented. Typed registration may constrain an untyped parent, so an
untyped parent supplies no substitution guarantee.

Dynamic dispatch is runtime-checked. The development frontend also checks the
named callbacks bound by entry-file `objk` declarations: callback parameter
count includes runtime and self; explicit callback annotations must agree with
the declared method contract where both specify a type. A callback reused by
multiple declarations must have the same declared contract. It checks known values
in callback returns, simple assignments, and direct calls between those
callbacks. The first pass recognizes literals, tracked local/parameter values,
known callback results, `okKText`, and construction of declared classes with
`okKNew`; known class inheritance and declared protocol adoption are accepted.
Raw string literals are not arena `text` handles. Unknown expression types stay
dynamic; this is not whole-program inference or a definite-return analysis.
These checks do not apply to arbitrary functions, indirect calls, dynamic
`okKSend*` expressions, or native AppKit signatures. No grammar or ownership
transfer contract changes. Released 2.4.9 predates this frontend check.

The runtime does not distinguish every Krypton dynamic value category.
Raw pointer calls bypass it. Result validation occurs after callback
side effects and cannot undo them.

### Protocols

Protocols are K-owned runtime records, not Objective-C protocols or parser
declarations. Define a nonempty name with `okKProtocol`, add requirements with
`doKRequireMethod`, then seal with `doKRegisterProtocol`. A protocol has at most
one sealed parent. Required names must be unique across that ancestry; arity is
0..2 and absent argument constraints must be 0. Object-class constraints follow
`okKObjectMethod` rules. No function pointer is needed for a requirement.

Adopt sealed protocols through `doKConform` before sealing the class. Duplicate
adoption on the same class is rejected. `doKRegister` validates all declared
protocols from the entire class ancestry against the new class's effective
method lookup. Each required method must exist with exactly matching arity and
argument/result class constraints, including unconstrained 0 positions. This
also revalidates inherited conformance when a subclass overrides methods.

`okKConforms` requires a readable object and sealed protocol. Conformance is
nominal, not inferred from matching methods. Adopting a child protocol implies
its parent; subclasses inherit declared conformance. Dispatch still uses normal
`okKSend` calls. Protocol-typed argument signatures, optional requirements,
default implementations, multiple protocol parents, variance, compiler checks,
and Objective-C protocol interoperability remain unimplemented.

### Arena And IDs

The runtime buffer must remain reachable while any ID is in use. Records store
integer IDs, not interior heap pointers: macOS GC does not traverse this object
graph. External native control/code pointers must not be placed in value fields.
Keep native controls separately, as the counter demo does.

Arena header qwords: capacity at 0, high-water end at 8, next ID at 16;
allocation blocks begin at 32. Each block has total aligned size and issued ID
in a 16-byte header, followed by payload. Payload kinds are class 1, method 2,
object 3, field 4, text 5; free payloads use 0 and allocation initialization uses
6; protocol is 7, requirement 8, conformance declaration 9. Class payload is
56 bytes, including a conformance-list ID after cleanup; method payload is 64
bytes, including three class constraints after the function pointer;
object/field payloads are 40 bytes; text payload is 32 bytes plus copied bytes,
including reference count and live state, rounded to qword alignment. These are
internal layouts, not a serialized format or a stable ABI.
Protocol payloads are 40 bytes `{kind,parent,name,requirements,sealed}`;
requirements use the 64-byte method layout with function pointer 0;
conformance declarations are 24 bytes `{kind,next,protocol}`. Protocol metadata
and its names persist for the runtime lifetime, like class/method metadata.

IDs start at 24 and increase by 16. Every allocation, including reused storage,
gets a fresh ID. Lookup scans block headers rather than treating an ID as an
offset. Stale strong access fails; weak reads remain 0 after slot reuse.
`okKRefCount` cannot recover a freed record's original kind, so callers must
pass object IDs, not arbitrary previously issued IDs. Do not add offsets to IDs.
IDs are local to their runtime; cross-runtime identity is not encoded.

Allocation uses first-fit free blocks or appends at high-water end. During
allocation, adjacent free blocks coalesce. A fitting block splits if the
remainder can hold a 16-byte header and at least one payload qword; smaller
remainders stay with the allocation. Free blocks at the allocation tail lower
the arena high-water mark immediately. No compaction exists: separated live
records can still fragment the arena. Classes, methods, and metadata names
remain allocated. Caller-created text is reclaimed at reference count zero. The whole arena is
host-GC-owned. Fresh IDs fail before exceeding the integer guard instead of
wrapping, after approximately 62 million allocations per runtime. Neither
unbounded allocation nor thread safety is promised.

## Native GUI Boundary

### macOS AppKit Event Contract

The development `k:okui`/`k:objk` facade adds table selection, key handlers and
live text-field notifications, implemented only in `stdlib/choc_macos.k`.
These are ordinary library calls, not new grammar or K-owned object features.
Windows/Linux adapters are unchanged; no new release version is implied.

- `okTable` returns a native NSTableView subclass in its existing scroll view.
  `okDataSource` retains its source; passing 0 detaches it. Sources must not
  strongly retain their own table. `okReload` refreshes the current model.
- `okSelectionNew` builds an autoreleased mutable index set; `okSelection`
  returns an autoreleased immutable snapshot. `okSelectionCount` counts indexes
  and `okSelectionAt` takes an ordinal, returning empty text when out of range.
  `okSelect`, `okSelectExtend`, `okSelectRow`, `okSelectAll`, `okSelectNone` and
  `okScrollTo` preserve native selection policy; invalid rows do not mutate
  selection. An accepted request does not override a delegate veto.
- `okOnKeyDown(table,funcptr(handler))` borrows `(table,event)` and consumes
  the event only when the handler returns nonzero. Zero preserves the base
  NSTableView method. Rebinding is per-table; callback pointer 0 detaches.
  Arbitrary foreign tables are rejected instead of silently modified.
- `okFieldOnChange(field,funcptr(handler))` borrows `(field)`, ignores its
  return value, and retains its own native delegate. It supports rebinding and
  detachment, refuses to replace a foreign delegate, and does not change the
  field's target/action. Programmatic `okSetText` does not synthesize edits.
- These APIs require the AppKit main thread and correctly declared callback
  ABIs. They do not add closures, compiler signature checks, automatic lifetime
  inference, or general protection against invalid native pointers.

Full contracts: [AppKit API guide](docs/objk_appkit_events_macos.md).
macOS `okScrollFrame` and `okScrollHidden` operate on a document view's enclosing
scroll container; non-scroll views return "0". `okViewWidth`/`okViewHeight` use
the NSRect return ABI. `okSameHandle` compares native pointer identity without
generic string equality. `okCopyText(text)` creates an independent NUL-terminated
Krypton text allocation; `okObjectText(object)` snapshots a native description,
with nil producing empty text. Copy before mutation or pool drain and keep the
result rooted. Raw `sbToString` interior pointers are not collector-safe roots;
the helpers do not repair general transitive/interior-pointer tracing.
Runnable sources: [live field tutorial](tutorial/macos/01_live_field.ks) and
[filter table](examples/objk/table_filter.ks). Regression:
`tests/macos/test_objk_table_events.k`, included in the Objective-K
runtime gate. Native GUI interactions were checked separately; the old full
compiler-suite results below remain historical and are not replaced by that gate.

The facade also exposes `okColumn`/`okColWidth`/`okRowHeight`, independent
`okOnClick`/`okOnDoubleClick` handlers taking `(table)`, image view/file loading,
menu check/enabled state and explicit window frame save/restore. Table actions
must not be mixed with generic `okClick` callbacks taking `(self,command,sender)`.
`okMenuEnabled` switches the entire menu to manual validation. Frame helpers
fail without a display and install no lifecycle delegate. Native class helpers
track pending names until registration; repeated allocation reuses the pending
handle, while a different pending superclass or conflicting registration fails
with a diagnostic. These are main-thread contracts, not a concurrent registry.
The [API guide](docs/objk_appkit_events_macos.md) specifies ownership and results;
`tests/macos/test_objk_appkit_controls.k` covers the control helpers.

`okWindowShouldClose(win,fnPtr)` and `okWindowOnClose(win,fnPtr)` install an owned
native window delegate: `(win)` returns integer 1 to allow a user close or 0 to
veto, while the later close notification ignores the result. Direct native
`close` bypasses the veto. `okAppOnOpenFile(app,fnPtr)` passes `(app,pathText)`
and returns integer 1 for handled; `okAppOnReopen(app,fnPtr)` passes
`(app,hasVisibleWindows)` and returns integer 1 to permit default native handling.
Pointer 0 detaches one hook; removing the last paired hook releases the delegate.
Foreign delegates are refused. Owners retain proxies; proxies do not retain
owners, and callbacks may detach themselves. No termination/session manager,
Finder bundle declarations, sandbox access, automatic window recreation, or
signature inference is implied. Window persistence on Quit remains explicit.
`tests/macos/test_objk_lifecycle.k` covers native close behavior and direct app
delegate dispatch. Drag/drop and asynchronous processes remain open.

### Development Compiler Input And Driver Contract

The shared frontend validates balanced delimiters and identifier positions
before function/import scanners. Binding, destructuring, loop and parameter
names must not be keyword tokens. `callback`, `process`, `go`, `fn` and `default`
remain reserved, not new contextual aliases. Rejection reports the source file;
an imported stream names its own module. Full source-location reporting remains
separate work. This preflight is not a complete semantic/type checker.

`func main() void { ... }` is malformed return syntax, not evidence that a valid
library needs an executable entry. Use `-> do` for action-only functions. Valid
function-only modules may emit `--ir` and be imported. Native `jxt` function
declarations describe foreign imports, not Krypton function bodies.

The development macOS backend checks direct calls to defined Krypton functions
against their declared parameter count, including imported helpers and forward
definitions. Missing or extra arguments fail before machine-code emission and
report the callee, expected/actual count and caller. Released 2.4.9 predates this
guard. Indirect calls, native message signatures and foreign declarations are
not made type-safe by this count check; `msg(view,"frame")` still cannot stand
in for `msgRectHeight(view,"frame")`. NSRect is returned in d0..d3, not as an
object handle in x0. No grammar change is introduced.

On macOS, executable builds require `just run` or `go run`; absence reports an
entry-point error without calling codegen. Frontend/backend failure must return
nonzero and cannot count an old executable as a successful output. The driver
stages codegen beside the destination, checks the result, and replaces the final
path only after success. Missing output directories and directory destinations
are errors. `--ir` writes IR to stdout and diagnostics to stderr; warnings do not
turn successful IR emission into failure. `-r` and `-e` inherit program stdout /
stderr and return its exit status without adding a newline to captured output.
These driver changes are macOS-specific; no untested Windows/Linux parity is
implied. `scripts/check_macos_driver.ks` exercises this contract.

### Model And Window Ownership

The macOS counter demonstrates a K-owned model, owned state, read-only dispatch,
native callbacks, and exactly-once cleanup on `Quit`. Native window handles must
stay raw pointers: converting `okWindow` results to text previously caused a
`setMinSize:` crash. [Demo](examples/objk/k_owned_counter_macos.ks).

Apps should use `k:okui` for controls and `k:objk_runtime_macos` for this object
core. OKUI/Choc currently adapt Apple APIs; a K-owned model does not make an
Apple window into a K-owned object. Keep native pointers outside integer fields.
Closing a window and terminating its application are separate lifecycle events;
wire cleanup to an explicit quit callback where the app owns K state.

The iOS adapters and SpriteKit visual layer are separate, Apple-backed work.
They have not verified this macOS-only core on iOS. No simulator build is proof
of object-runtime portability. [iOS roadmap](docs/ios_native_roadmap.md).

## Validation And Outstanding Work

Run from checkout root with current macOS bootstrap artifacts:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_objk_runtime_macos.ks
./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_objk_runtime_macos.ks --gui
./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_okui.ks
./build.sh test
```

`--gui` needs a desktop session. The intentional null-call trap is expected,
not a checker regression. Core checks cover imports, indirect calls, ancestry,
dispatch, declaration lowering, text, fields, lifetime/cleanup, weak references,
and failure cases;
they inspect dependencies to reject Apple object frameworks. Reuse tests run
2,000 object/field/name cycles in a 1KB arena without high-water growth, test
expired weak IDs and stale strong access, GC, and allocation during cleanup.
Additional checks cover free-block merging/splitting, owner-field reads from
multiple child hooks, runtime class constraints, and typed override failures.
Protocol checks cover inherited/multiple adoption, exact signatures, required
methods, subclass override revalidation, sealing/duplicate guards, and GC.

Last recorded full macOS suite: 70 pass, 1 failure
(`test_negative_nums.k` assertion), 8 skips. This is not an all-green release
gate. macOS skips
`test_bytes.k` and `test_process_win_argv.k` because `ptrAdd`/`ptrToInt` are
not emitted there. Generic-looking module names do not establish parity.

Next work, in order:

1. Extend fragmented-workload stress checks and evaluate compaction.
   Splitting, coalescing, tail trimming, and explicit text ownership are implemented.
2. Add deeper compiler signature diagnostics and result ownership contracts. Runtime
   integer/text/class/protocol checks are not compile-time type safety.
3. Add inline Objective-K method bodies, fields, ownership annotations, and
   multiple protocol conformances without exposing runtime setup locals.
4. Move more Choc widget state/events into K-owned objects and generate native
   adapters without losing pointer identity or platform ABI correctness.
5. Repair remaining macOS pointer primitives, negative-number regression, import
   graph depth/global type propagation, then run platform-specific parity tests.

Do not claim ARC, cycle collection, thread-safe dispatch, dispatch caching,
a complete Objective-K language, a Cocoa replacement, or a released
2.4.6 from this work. Rebuild compiler/driver seeds only when compiler/driver
source changes; runtime-module edits are compiled into their consuming programs.
