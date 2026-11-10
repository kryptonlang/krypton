# QBI — Quantum Binary Interface

**Status:** v0.1 — DRAFT. Nothing in this specification is implemented, bound
to a compiler flag, or committed to ABI stability.
**Scope:** macOS arm64 first, in lockstep with KBI. ELF/PE follows or never.
**Flag:** none (`--kbi` is the only KBI flag; QBI has no build plumbing yet).
**Sibling spec:** `docs/design/KBI.md` — KBI v0.2 is the system ABI (register
conventions, `rBUMP` in x28, FFI thunks). QBI layers on top of it.

Deliverable: spec first, reference implementation much later, code lives in
Krypton. This document exists so KBI.md stays a focused systems-ABI spec;
QBI introduces distinct abstractions (state vectors, gate dispatch) that do
not belong there.

## 1. Overview

The Quantum Binary Interface (QBI) defines register conventions, state-vector
allocation rules, and gate-dispatch thunks for executing quantum operations
within the native Krypton runtime.

QBI is not a variant of the classical ABI. It reserves its own architectural
state and only interoperates with KBI at well-defined boundaries (allocation
of scratch context, FFI thunk transitions).

## 2. Register layout

QBI reserves dedicated register state alongside KBI:

- **`rQCTX` (`x27`)**: Quantum Circuit Context Pointer. Points to the active
  state-vector buffer and gate execution queue.
  - x27 sits in KBI's "Free / unallocated (AAPCS non-volatile)" band (KBI §3).
    Reserving it for QBI shrinks that band and is therefore an ABI-normative
    decision, not an implementation detail. KBI §3 must be updated in the
    same change that first lands QBI code.
- **`rBUMP` (`x28`)**: Inherited from KBI v0.2 for frame-scoped classical
  memory allocations during circuit assembly. QBI does not reinterpret x28.

Everything else (x0–x7 payload slots, x8 result pointer, x16/x17 IP0/IP1,
x18 platform-reserved, x29/x30 fp/lr) keeps KBI §3 semantics unchanged.

## 3. Allocation primitives

Quantum state vectors require strict 16-byte vector alignment:

- **`qbi_state_alloc(num_qubits)`**: Reserves 2^N complex amplitude slots
  within `rQCTX`. Distinct from `rBUMP` (x28): quantum state is **not**
  bump-freed at frame or call scope, its lifetime is circuit-scoped.
  Interaction with the GC frontier (KBI §5.5) is undefined and must be
  resolved before implementation.
- **`qbi_gate_apply(op_code, target_qubit, control_qubit)`**: Emits the gate
  execution thunk (see §4) for the given opcode. Reads/writes the state
  vector through `rQCTX`.

Both primitives currently exist only as a calling-convention sketch; no
IR opcodes, builtins, or runtime support are implemented.

## 4. FFI Boundaries

When calling foreign simulator dynamic libraries (e.g., C/Metal acceleration
primitives), `rQCTX` (`x27`) and `rBUMP` (`x28`) must be flushed to the stack
frame before the call and reloaded after it — the same discipline KBI applies
at the C/ObjC/syscall boundary (KBI §5.4 `blr`):

- Flush `rBUMP` to the bump cell and `rQCTX` to an adjacent cell/slot before
  the thunk crossing.
- Foreign code preserves AAPCS non-volatile registers as usual, but must not
  see live KBI/QBI state in x27/x28.
- Reload both after `blr` returns; a simulator that never returns normally
  leaves the flushed cells as the recoverable context.

Crossing rules:

- Krypton→Krypton calls never flush/reload — KBI §5.4 applies as written.
- Krypton→simulator-FFI calls always flush/reload x27 and x28.
- Simulator→Krypton re-entry is out of scope for v0.1.

## 5. Open questions (before this becomes implementable)

- Width of the `rQCTX` context and whether it is ever callee-saved k→k
  (KBI §3 changes if so).
- Whether `qbi_state_alloc` arenas are circuit-lifetime or process-lifetime,
  and how the GC sees them.
- x18 remains untouchable (KBI §4). Can QBI tag bits live in x27 pointers?
- Are gate ops always external (FFI), or can a native simulator live behind
  `--kbi` the way `__kbi_alloc` did?
- ELF/PE (KBI §8) for QBI: macOS-arm64-first like KBI, or never?
- Opcode space for `qbi_gate_apply`: what does v0.1 actually enumerate?
