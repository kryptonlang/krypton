// B2 multi-return — return a,b packs into an array; let x,y = f() destructures.
// FE-lowered over the A5 array buf builtins. No backend change beyond A5.
func divmod(a, b) { emit a / b, a % b }
func minmax(x, y) { if x < y { emit x, y }  emit y, x }
func three()      { emit 1, 2, 3 }
func nameAge()    { emit "bob", 30 }

just run {
    let q, r = divmod(17, 5)
    if q != 3 || r != 2 { print("[FAIL] divmod"); exit("1") }
    let lo, hi = minmax(8, 3)
    if lo != 3 || hi != 8 { print("[FAIL] minmax (multi-return in branch)"); exit("1") }
    let a, b, c = three()
    if a != 1 || b != 2 || c != 3 { print("[FAIL] three"); exit("1") }
    let nm, age = nameAge()
    if nm != "bob" || age != 30 { print("[FAIL] mixed string/int"); exit("1") }
    print("[PASS] multi-return (2/3 values, in-branch, mixed string/int)")
}
