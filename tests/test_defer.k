// B1 defer — runs deferred calls at function exit in LIFO order; covers early
// returns + fall-through. FE-lowered (relocated to exits in irFuncIR); no backend.
let order = ""
func track(s) { order = order + s }

func lifo() {
    defer track("1")
    defer track("2")
    defer track("3")
    track("b")
    // exit order: body then 3,2,1 -> "b321"
}
func early(x) {
    defer track("E")
    if x > 0 { emit 1 }
    emit 0
}
just run {
    lifo()
    if order != "b321" { print("[FAIL] LIFO order: " + order); exit("1") }
    order = ""
    let r1 = early(1)            // E runs before the early return
    if r1 != 1 { print("[FAIL] early return value"); exit("1") }
    if order != "E" { print("[FAIL] defer on early return: " + order); exit("1") }
    order = ""
    let r0 = early(0)            // E runs at fall-through
    if r0 != 0 { print("[FAIL] fallthrough return value"); exit("1") }
    if order != "E" { print("[FAIL] defer on fallthrough: " + order); exit("1") }
    print("[PASS] defer (LIFO, early-return + fall-through, function-scope)")
}
