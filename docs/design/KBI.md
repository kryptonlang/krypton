# KBI — Krypton Binary Interface

**Status:** v0.2 — decisions locked; reference implementation in progress.
**Scope:** macOS arm64 (`compiler/macos_arm64/macho_arm64_self.k`) first. ELF/PE ports follow after parity is proven.
**Flag:** `--kbi` (opt-in, alongside default ABI)

Deliverable: spec + reference implementation **in [t3m3d/kbi](https://github.com/t3m3d/kbi)**; code lives in Krypton.

---

## 1. Purpose

KBI is Krypton's native internal calling convention and allocation path:

1. **rBUMP in x28**: x28 permanently reserved as the live bump-allocation
   frontier. Initialized once at program entry (`__main__`); preserves across
   internal calls.
2. **Register-passed small payloads**: small enums / payload structures that
   fit in x1..x7 pass by value directly in registers — no stack spill.
3. **C-ABI boundary isolation**: crossings to C libraries, syscalls, ObjC stay
   behind existing `__stubs` / thunks; they spill to host C ABI before dispatch.

## 2. Distribution model

- **Opt-in**: `--kbi` enables KBI alongside the default ABI for parity testing.
  Without `--kbi`, output must be bit-identical to today.
- Chaperoning for inspection: `x28` never changes the default path; internal fast path engineering happens behind `--kbi` until tests pass.

## 3. Register map (macOS arm64)

| Reg | Role | Callee-saved (k->k) | FFI |
|-----|------|----------------------|-----|
| x0  | Scalar return, payload slot 1 | n/a | OS volatile |
| x1–x7 | Payload slots 2..8 | OS volatile / KBI volatile | OS volatile |
| x8  | Result-pointer for compound returns (see §5.2) | OS volatile | OS volatile |
| x9–x15 | Scratch | OS volatile | OS volatile |
| x16 | IP0 — syscall / stubs | n/a | OS volatile |
| x17 | IP1 — linker veneers | n/a | OS volatile |
| x18 | Platform-reserved | n/a | n/a |
| x19–x21 | Inline BUILTIN scratch (existing); **callee-must-save** | yes (AAPCS) | yes |
| x22–x27 | Free / unallocated | AAPCS non-volatile | OS non-volatile |
| x28 | **rBUMP — permanent bump frontier** | AAPCS non-volatile | preserved |
| x29/x30 | fp / lr | yes (AAPCS) | yes |

## 4. Stack discipline

- SP stays 16-byte aligned at every public and internal call boundary.
- `x29` = FP, `x30` = LR untouched by KBI payload logic.
- `x18` never touched by KBI.
- Eval stack remains the spill path for spills ≥ 8 args or large composites.

## 5. Calling convention

### 5.1 k->k arguments

- Up to 8 GP registers: args land in x0..x7 (left-to-right).
- Small enum/payload structures → pass by value in x1..x7 on top of x0 / returned in x0.
- Larger complex structs -> pass by reference (pointer in the same slot).
- Arguments beyond 8: spill onto the stack per standard AAPCS64 (args pushed
  beyond x7 onto the stack frame).

### 5.2 k->k return values

- Scalar/pointers -> `x0`.
- Multi-register or larger compound structures -> returned via `x8` as a
  result-pointer (comp-result convention).

### 5.3 Varargs

None. All internal Krypton functions have fixed arity.

### 5.4 FFI (C / ObjC / syscalls)

- Internal k->k calls -> KBI rules.
- Crossing to external C, OS syscalls, or runtime hooks -> C FFI thunks; args
  spill to host C ABI registers before dispatch; callee (C ABI) preserves
  non-volatile regs, including x28.
- ObjC remains via existing selector thunk rules (x0=self, x1=sel); never
  applies KBI payload shifts across the boundary.

### 5.5 rBUMP lifecycle

- `__main__` entry initializes rBUMP from the `__DATA` bump cell.
- Bump allocator bumps x28 directly for allocation sizes.
- `&mut __rt_alloc` stores/loads rBUMP to/from the cell on entry/exit so GC
  reads the frontier from memory as today.
- FFI calls that may GC flush rBUMP to the bump cell before the boundary and
  reload on return.

## 6. Implementation plan (in-flight, this repo)

Order of work (committed to default; roll-back by removing `--kbi`):

1. `--kbi` flag in `compile.k` arg scan (this step: parse-only plumbing).
   IR emission adds a `; KBI: 1` header marker when `--kbi` is set.
2. `macho_arm64_self.k` — plumb `--kbi` into backend entry; seed rBUMP in
   `__main__` (x28 = bump_cell+0 after the mmap block). Default output stays
   byte-identical (g_KBI="0" path untouched by the new `ldr x28, [x9]`).
3. `__kbi_alloc`: second, self-contained allocator helper (Option A). **DONE.**
   - `emitKbiAllocHelper()` — 126 instr. Clone of `__rt_alloc` with the BUMP
     source swapped from `__DATA bump cell` to x28 (rBUMP), plus a cell
     writeback so the GC's frontier stays coherent.
   - `g_KBI` dispatch in `emitTextFromIR` selects `__kbi_alloc` when
     `--kbi` is on; default path still uses `__rt_alloc` unchanged.
   - `allocInstrCount()` = 126 (KBI) / 123 (default) drives `computeTextSize`
     and the fLoad/fBox/fFormat anchors.
   - All in-helper jump offsets re-checked: cbz/cbnz/b_cond are
     instruction-relative-to-current, not pc+4.
4. FFI thunks: flush/reload rBUMP around external calls. **Done.**
   - `emitKbiFlushBump(instrIdx, textOff)` / `emitKbiReloadBump(instrIdx, textOff)`:
     2 instr each (adrp x17, cell; str/ldr x28, [x17]).
   - Foreign dispatchers (`objc_msgSend_*`) and the generic `CALL_FUNC` foreign
     branch wrap the actual call with flush/reload. `callPtr` (`blr x16`) wraps
     too. All wrapped sites are `g_KBI` compile-time gated (default ABI is
     byte-identical).
   - Krypton-to-Krypton calls go through the same dispatcher but skip the FFI
     wrapper — the callee may itself advance rBUMP (via `__rt_alloc`).
   - Regression verified: `test_hello.k`, `test_switch.k`, `test_enum_exhaustive.k`,
     `test_to_int.k`, `test_objk_observers.k` — all PASS under `--kbi`.
   - Root cause crash fix: earlier universal flush/reload produced silent
     instruction-count skew in non-foreign sites. Gated on `fidx >= 0`.
4. Enum payload register routing behind `g_kbi`; re-verify
   `test_enum_payload.k` byte-identical behavior. **Pending.**
   (Blocked by pre-existing frontend self-host bug; `tests/test_enum_payload.k`
    can't compile until that's resolved.)
5. Enum payload register routing behind `g_kbi`; re-verify
   `test_enum_payload.k` byte-identical behavior. **Pending.**

## 7. Gating tests before any promotion beyond `--kbi`

- Full suite passes byte-identically under `--kbi` == default output for all
  `tests/` targets.
- `tests/macos/test_objk_observers.k`, `test_enum_payload.k`,
  `test_enum_exhaustive.k`, etc. stay green.
- GC stress (`gc_auto_collect`, `gc_alloc_count`) green under both modes.

## 8. Open decisions

- Whether KBI stay-macho-only vs. left open to ELF/PE (answer: macOS arm64 only initially — ✓ locked).
- `--kbi` init: rBUMP seed strategy at entry (always reload from cell vs. zero-init if allocator untouched).
- Whether the x18-free guarantee is ever leveraged for KBI pointer tags.
- Whether `--kbi` defaults flip in a stage where the default ABI is retired.

---

## Appendix A. Legacy `--ir` regression status

Self-hosted frontend (`kcc-arm64`) currently miscompiles `let`/`func` sources
for reasons *independent of KBI*; under the current state of the backend all
harness verification must use the committed shipped `kcc-arm64` frontend binary
or clang-bootstrap. See KBI Implementation Log for the bug history.
