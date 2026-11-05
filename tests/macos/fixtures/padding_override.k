func padLeft(s, width) { emit "MODULE:" + s }
just run {
    if padLeft("7", 4) != "MODULE:7" { print("[FAIL] builtin shadowed module"); exit(1) }
    print("[PASS] module padding overrides builtin")
}
