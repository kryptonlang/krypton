func zero() { emit 40 }
func sum(left, right) { emit left + right }
func forward(value) { emit later(value) }
func later(value) { emit value + 1 }
just run {
    if sum(zero(), forward(1)) != 42 { print("[FAIL] exact call arities"); exit(1) }
    print("[PASS] exact call arities and forward declarations")
}
