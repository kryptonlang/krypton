# Kryptos System ABI Specification (KSABI v1)

Status: **Draft v1** — 2026-11-12. The object-model sections marked
*verified* are normative and describe the shipped `k:objk_runtime` (checked
in tree at commit f92fc73d; byte-for-byte identical on macOS arm64 and
Linux x86_64). Sections marked *specified* define the official contract
for system services and process lifecycle hooks; implementations land in
milestones tracked in the SmackUI roadmap (Milestones 12–15) and are not
yet wired into a KryptOS image. Do not rely on unmarked behavior.

Audience: authors of userland applications for KryptOS (via SmackUI /
`k:objk_runtime`), and system-service implementers.

## 1. Scope and non-goals

KSABI defines:

* The object-model ABI every process speaks: arena layout, handle format,
  record layouts, message send contract, ownership policies.
* The naming and discovery of official system services (selector names and
  service identifiers).
* The process lifecycle hooks a well-behaved userland application runs.

Non-goals:

* No file format, package, or distribution contract (see `kr` / socam).
* No kernel syscall ABI. KryptOS processes currently reach POSIX/libSystem
  via direct extern calls; KSABI sits above that layer.
* No cross-process handle passing. Handles are process-local (see §4).
* No wire protocol. Service discovery is in-process only in v1.

## 2. Object model (verified)

Runtime entry point: `import "k:objk_runtime"`. The compiler auto-imports
the module when Objective-K declarations (`objk object`, `objk protocol`,
`objk @implementation`) are used.

An instance of the runtime is a value returned by `okKRuntime(capacity)`:
a single arena buffer (`bufNew(capacity)`). `capacity` bytes must be in
`[64, 1048576]`. All handles handed out by one runtime refer to records in
that arena.

### 2.1 Handle invariants

* A handle is an **integer identifier, not an interior pointer**.
* The first usable handle is `24`; each handle ID increments by `16`.
* High-water enforcement: allocation fails with a fatal error (`okKFail`)
  if the handle counter exceeds `999999984` (`16 × 10^8`).
* `okKLookup(runtime, handle)` validates: `handle >= 24`,
  `handle < next_handle`, `handle % 16 == 8`. Any violation fatals.
* Handles are valid only in the process that created the runtime.
  Serialization of a handle across a process boundary is meaningless.

### 2.2 Arena layout

All multi-byte words are stored little-endian via `bufSetQwordAt` /
`bufGetQwordAt`. The arena header is fixed-size:

| Offset | Field | Meaning |
| ------ | ----- | ------- |
| 0      | `capacity` | total arena bytes (`bufNew` size) |
| 8      | `bump`   | bytes in use (monotonic high-water of block end) |
| 16     | `next_handle` | next handle ID to issue (starts at 24) |
| 24     | reserved | kind tags written per block |
| 32..   | blocks   | variable-size records |

Each record block begins with a 16-byte header:

| Offset | Field | Meaning |
| ------ | ----- | ------- |
| 0      | `size` | block size in bytes, 8-byte aligned, **including this 16-byte header** |
| 8      | `handle` | the ID handed out for this block |
| 16     | `kind` | record kind (below); `0` = free block |

Allocation fits records into the first free region (first-fit with
coalescing of adjacent free blocks); if none fits before the bump limit,
a new block is appended. `capacity` exhaustion fatals with detail. Freeing
(`doKFree`) sets `kind = 0` and coalesces trailing free runs. There is no
compaction.

### 2.3 Record kinds

| Kind | Record | Notes |
| ---- | ------ | ----- |
| 1 | class | registered with `doKRegister` before instantiation |
| 2 | method | linked into class `methods` chain |
| 3 | object | instance of a class |
| 4 | field | linked into object `fields` chain |
| 5 | text | UTF-8 byte string record |
| 7 | protocol | sealed by requirement registration |
| 8 | requirement | protocol member |
| 9 | conformance | class ↔ protocol link |
| 10 | witness table | slots → requirement + `fnPtr` |
| 11 | observer node | field observers |

(Kind 6 is the untyped allocated-block tag historically used for
scratch space; it carries no interpretive contract.)

### 2.4 Record layouts

All layouts are 8-byte words at relative offsets (byte offsets from the
record base, matching `okKRead(runtime, handle, offset)`).

**class { kind=1, parent(8), name(16), methods(24), registered(32), sealed(40), conformances(48), observers(56) }**

* `parent` — superclass handle, or `0` for the root class.
* `name` — text handle (§2.4 text).
* `methods` — singly-linked method chain, newest first (prepend).
* `registered` — `0` until `doKRegister`; instances cannot be created from
  an unregistered class (`okKNew` fatals).
* `conformances` — chain of kind-9 declarations (prepend).

**method { kind=2, next(8), name(16), arity(24), fnPtr(32), firstClass(40), secondClass(48), resultClass(56) }**

* `arity` is `0..2`. Argument classes and result class are class handles or
  the builtin type sentinels from §2.5; `0` means untyped.
* `fnPtr` is a function pointer (Krypton `funcptr`) with the calling
  convention from §2.6.

**object { kind=3, klass(8), refs(16), fields(24), alive(32), observers(40) }**

* `klass` — owning class handle.
* `refs` — weak-release counter participation: starts at 1; `doKReleaseText`
  analogs decrement it; at 0 the object is unusable. `okKAlive` fatals on 0.
* `fields` — chain of kind-4 records, newest first.
* `alive` — `1` alive, `0` released.
* `observers` — chain of kind-11 nodes (per-object KVO-style observers).

**field { kind=4, next(8), name(16), value(24), policy(32) }**

* `policy`: `0` borrowed, `1` owned object, `2` weak object, `3` owned text.
* Weak fields are nulled by release paths; owned text fields retain/release
  the stored text handle on assignment.

**text { kind=5, length(8), refs(16), state(24), bytes...(32+) }**

* `length` — byte length of the UTF-8 payload (max 100000).
* `refs` — reference count; starts at 1. `okKRetainText`/`doKReleaseText`
  guard against release-then-use and refcount overflow (≥ 10^9 fatals).
* `state` — `1` valid, `0` after final release (reads of stale text fatal).

**requirement { kind=8, next(8), name(16), arity(24), slot(32), firstClass(40), secondClass(48), resultClass(56) }**

**protocol { kind=7, parent(8), name(16), requirements(24), sealed(32) }**

**conformance { kind=9, next(8), protocol(16), witness(24) }**

**witness table { kind=10, count(8), entries[](16) }** — each entry is
`{ requirement(16), fnPtr(24) }`, i.e. `16 + count × 16` bytes total.

**observer node { kind=11, next(8), name(16), fnPtr(24) }**

### 2.5 Builtin type sentinels

| Value | Sentinel | Meaning |
| ----- | -------- | ------- |
| 0 - 1 | integer type sentinel (i.e. `-1`) | untyped is `0`; `okKTypeInteger()` returns `-1` |
| 0 - 2 | text type sentinel (i.e. `-2`) | `okKTypeText()` returns `-2` |

Signed comparison with `okKCheckSignatureType` enforces match on method
registration.

### 2.6 Message send contract

* Dispatch: `okKInvoke` walks the object's class chain; a method's `name`
  match is by handle identity of the stored text (pointer-equal name
  records are deduped by `okKText` allocation) — semantically: first own
  method on the chain wins, exactly once per class.
* Arity: 0, 1, or 2 positional `a`, `b` words. Longer argument lists must
  be packed by the caller into a struct value; `okKInvoke`
  does not variadically scan.
* Return: a single word in the value slot.
* Protocol requirements are dispatched through witness tables, not selector
  lookup; a class that claims conformance without providing the method
  fatals at `okKBuildWitness` time.
* `super` send (`okKSuper`) re-targets dispatch at `parent(klass)` and
  errors if the object's class is not in the defining class's ancestry.

### 2.7 String and identity rules

* Text equality is by content (`okKTextEquals`), not handle identity.
* Record handles must never be compared with `==` across separately
  allocated records when structural equality is meant; see
  `stdlib/smack/view.k` for the structural-identity pattern.

## 3. Service interface (specified, not yet implemented)

This section defines the **official system selectors** a KryptOS userland
application may rely on. v1 services are in-process facades over the
K-owned runtime, not RPCs. Selectors are Pascal-case-free, camelCase, with
the class name acting as namespace (Objective-K convention).

### 3.1 Service registry

`import "k:sys"` (planned) exports `okKSysService(name)` returning a
service object, or `0` if the service is unavailable in this image. The
registry is fixed at image build time; v1 defines:

| Service key | Selector set | Backing milestone |
| ----------- | ------------ | ----------------- |
| `process` | `currentProcess`, `terminateWithStatus:` (arity 1) | M12/M15 |
| `display` | `mainDisplay`, `displayList` | M12/M14 |
| `input`   | `eventSource`, `addEventHandler:` (arity 1 fnPtr) | M14 |
| `filesystem` | `homeDirectory`, `temporaryDirectory` | M15 |
| `clock` | `uptime`, `sleepMilliseconds:` (arity 1 int) | M15 |
| `log` | `log:` (arity 1 text), `logLevel`, `setLogLevel:` | M15 |

Availability is advertised through the KryptOS image manifest, not probed
by crashing on missing services: callers must handle `0`.

### 3.2 Process lifecycle hooks

A KSABI-conformant application executes this hook order:

1. `__main__` (the `just run` block) — application entry.
2. `systemWillStart` — optional `objk` message to the process service
   object; invoked before `__main__`'s first service call. Lets a
   service-managed app defer window creation until the session is up.
3. `__main__` body.
4. `systemWillTerminate` — invoked with the pending exit status (int) if
   the process service calls `terminateWithStatus:`; after all hooks return,
   the arena is freed and the process exits with that status. Plain
   `exit()` from Krypton bypasses hooks (documented as non-conformant).
5. No `atexit`, no finalizers. Reference release is caller discipline.

Hook registration: `okKSysSetHook(which, fnPtr)` (planned) where `which`
is `0` = willStart, `1` = willTerminate. At most one hook per `which` per
process; re-registration replaces. Hooks are invoked on the calling thread;
KryptOS services must not call back into hooks re-entrantly.

### 3.3 Version negotiation

`okKSysVersion()` (planned) returns three integers packed as
`major*10000 + minor*100 + patch` (e.g. `10000` == 1.0.0). An application
built against KSABI v1 must refuse to run on images reporting `< 10000`,
or degrade explicitly.

## 4. Portability and stability guarantees

| Guarantee | v1 status |
| --------- | --------- |
| Arena layout §2.2 stable across releases | yes — additive only (new kinds may appear; new offsets appended only for new records) |
| Kind values §2.3 frozen | yes |
| Handle ID monotonicity (§2.1) | yes |
| `okKRead/okKWrite` offsets for existing kinds frozen | yes |
| Text UTF-8 payload layout | yes |
| Service selectors §3 | normative names frozen in v1; availability per image |
| Handle values comparable across runs | no |
| Arena serialized to disk | no |

## 5. Conformance checklist (userland authors)

* Never fabricate handles. Obtain every object from the runtime.
* Do not stash handle `0` — it is the nil/sentinel value in every context.
* Match method arity exactly; superfluous args are not discarded silently.
* Release text you own; weak-release paths expect policy `2`.
* If you build witness tables by hand, slot numbering starts at `1` and
  ascends in declaration order of the parent-most protocol first.
* Handle comparisons across separate runtime instances are meaningless.

## 6. Reference implementation

* `stdlib/objk_runtime.k` — K-owned runtime (both backends, byte-identical).
* `tests/test_objk_lifetime.k`, `tests/test_objk_protocols.k`,
  `tests/test_objk_witness.k` (macOS arm64); Linux run of the same suite in
  the KryptOS VM (128/128 pass, 2026-11-12).
* `stdlib/smack/` — pure-Krypton software UI toolkit on this ABI.
* `docs/objective_k.md`, `docs/objk_runtime_macos.md` — guides.
