func check(actual, expected, name) {
    if actual != expected { print("[FAIL] " + name + ": " + actual); exit(1) }
}
func nested(s) { emit "[" + padLeft(padRight(s, 3, "x"), 5, "0") + "]" }
just run {
    check(padLeft("7", 4, "0"), "0007", "left")
    check(padRight("7", 4, "0"), "7000", "right")
    check(padLeft("7", "4", "#"), "###7", "numeric width")
    check(padLeft("long", 2, "0"), "long", "no truncation")
    check(padRight("long", 0, "0"), "long", "zero width")
    check(padLeft("X", 4, "ab"), "abaX", "partial left pad")
    check(padRight("X", 4, "ab"), "Xaba", "partial right pad")
    check(padLeft("X", 9, ""), "X", "empty pad")
    check(padRight("", 3, "x"), "xxx", "empty source")
    check(padLeft(7, 4, 0), "0007", "integer values")
    check(padLeft(-7, 4, "0"), "00-7", "negative integer text")
    check(padLeft("7", -1, "0"), "7", "negative width")
    check(nested("7"), "[007xx]", "nested function padding")
    let i = 0
    while i < 100 {
        check(padLeft("7", 8, "0"), "00000007", "repeat stack balance")
        i += 1
    }
    print("[PASS] native padding")
}
