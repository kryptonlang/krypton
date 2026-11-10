// A6 static locals — persist across calls, init once, per-function independent.
// Lowered to a uniquely-mangled module global (FE); no backend change.
func counter() { static let n = 0  n += 1  emit n }
func other()   { static let n = 100  n += 1  emit n }   // same name, independent
func acc(x)    { static let total = 0  total += x  emit total }

just run {
    if counter() != 1 { print("[FAIL] c1"); exit("1") }
    if counter() != 2 { print("[FAIL] c2"); exit("1") }
    if counter() != 3 { print("[FAIL] c3"); exit("1") }
    if other()   != 101 { print("[FAIL] other init/independent"); exit("1") }
    if other()   != 102 { print("[FAIL] other persist"); exit("1") }
    if counter() != 4 { print("[FAIL] counter independent of other"); exit("1") }
    if acc(5)  != 5  { print("[FAIL] acc 5"); exit("1") }
    if acc(10) != 15 { print("[FAIL] acc accumulate"); exit("1") }
    print("[PASS] static locals (persist, init-once, per-function independent)")
}
