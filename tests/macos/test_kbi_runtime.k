// KBI runtime module smoke test: exercises kbiRuntime / kbiAlloc /
// kbiAllocCount / kbiAllocAvailable / kbiReset and asserts the arena
// ledger (used bytes, alignment, count, reset).

import "k:kbi_runtime"

just run {
    kp("KBI Runtime Test")
    kp("=================")

    // Basic creation and allocation
    let arena = kbiRuntime(4096)
    let p1 = kbiAlloc(arena, 16)
    let p2 = kbiAlloc(arena, 48)
    let p3 = kbiAlloc(arena, 100)

    // Offsets must be strictly increasing and aligned
    if p1 != 32                  { kp("[FAIL] p1 expected 32, got " + p1); exit("1") }
    if p2 != 48                  { kp("[FAIL] p2 expected 48, got " + p2); exit("1") }
    if p3 != 96                  { kp("[FAIL] p3 expected 96, got " + p3); exit("1") }

    // Allocation counter and available-bytes ledger
    if kbiAllocCount(arena) != 3 { kp("[FAIL] count"); exit("1") }
    if kbiAllocAvailable(arena) != 4096 - 200 { kp("[FAIL] available"); exit("1") }

    // Reset rolls the cursor back to 32
    kbiReset(arena)
    if kbiAllocCount(arena)     != 0 { kp("[FAIL] reset count"); exit("1") }
    if kbiAllocAvailable(arena) != 4064 { kp("[FAIL] reset available"); exit("1") }
    let p1b = kbiAlloc(arena, 16)
    if p1b != 32 { kp("[FAIL] after reset p1b expected 32, got " + p1b); exit("1") }

    // Alignment: odd requests bump to 8-byte multiples
    kbiReset(arena)
    let pa = kbiAlloc(arena, 3)
    let pb = kbiAlloc(arena, 7)
    if pb - pa != 8              { kp("[FAIL] alignment"); exit("1") }

    kp("[PASS] kbi_runtime (init, alloc, count, available, reset, alignment)")
}
