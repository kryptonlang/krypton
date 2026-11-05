import "k:string_utils"
just run {
    if padLeft("7", 4, "0") != "0007" { print("[FAIL] module left"); exit(1) }
    if padRight("X", 4, "ab") != "Xaba" { print("[FAIL] module right"); exit(1) }
    if padLeft("X", 9, "") != "X" { print("[FAIL] module empty pad"); exit(1) }
    print("[PASS] padding stdlib import")
}
