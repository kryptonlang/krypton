// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// kbi_runtime — Krypton Binary Interface bump-allocator runtime.
//
// Stand-alone arena module backed by a single `bufNew` allocation. The
// arena is a flat, GC-scanned buffer with three 8-byte header cells:
//
//   +0   capacity   — total bytes reserved (including this header)
//   +8   cursor     — byte offset of the next free slot (starts at 32)
//   +16  count      — number of allocations performed since the last kbiReset()
//
// All allocations are 8-byte aligned and bump-only (no free list) — this is
// the Phase 2 rBUMP promotion target; it is a byte-for-byte functional
// equivalent of the inline alloc the macho_arm64_self.k backend emits under
// --kbi, just expressed as a reusable Krypton module.
//
// Handles returned by `kbiAlloc` are byte offsets into the arena buffer
// (0-based, relative to `arena`); callers use `bufGetQwordAt(arena, off + N*8)`
// to read/write via the same style as objk_runtime.

module kbi_runtime

// Create a new KBI arena with `capacity` bytes reserved. Capacity must be
// at least 64 (one full KBI header plus one 8-byte payload slot) and no
// more than 64 MiB. The first payload slot begins at byte 32.
func kbiRuntime(capacity) {
    if capacity < 64 || capacity > 67108864 {
        print("kbi: capacity must be in [64, 67108864]\n")
        exit("1")
    }
    let arena = bufNew(capacity)
    bufSetQwordAt(arena, 0, capacity)
    bufSetQwordAt(arena, 8, 32)
    bufSetQwordAt(arena, 16, 0)
    emit arena
}

// Allocate `bytes` from the arena, aligned to 8 bytes. Returns the byte
// offset of the freshly claimed slot (into `arena`). Exits on exhaustion.
func kbiAlloc(arena, bytes) {
    if bytes <= 0 { print("kbiAlloc: bytes must be > 0"); exit("1") }
    let aligned = ((bytes + 7) / 8) * 8
    let cursor = bufGetQwordAt(arena, 8)
    let cap = bufGetQwordAt(arena, 0)
    if cursor + aligned > cap {
        print("kbiAlloc: arena full (cursor=" + cursor + " cap=" + cap + " need=" + aligned + ")\n")
        exit("1")
    }
    bufSetQwordAt(arena, 8, cursor + aligned)
    bufSetQwordAt(arena, 16, bufGetQwordAt(arena, 16) + 1)
    emit cursor
}

// Number of allocations performed since the last kbiReset() (or since arena
// creation). Useful for stress assertions.
func kbiAllocCount(arena) {
    emit bufGetQwordAt(arena, 16)
}

// Bytes still available for allocation in the arena.
func kbiAllocAvailable(arena) {
    emit bufGetQwordAt(arena, 0) - bufGetQwordAt(arena, 8)
}

// Reset the cursor to the first payload slot and zero the allocation count.
// Existing data in the arena is NOT zeroed (callers are responsible for
// their own invalidation), but the GC will see the reclaimed region as the
// bump pointer rolls back.
func kbiReset(arena) {
    bufSetQwordAt(arena, 8, 32)
    bufSetQwordAt(arena, 16, 0)
    emit 0
}
