// A4 (printf-style): format(fmt, ...) / printf(fmt, ...) with a string-literal
// format are expanded at compile time to a concat of literal pieces + args.
// %s/%d/%f insert the arg (ADD auto-stringifies ints); %% = literal %. Pure FE,
// all backends. printf raw-writes (no extra newline).
just run {
    if format("x=%s y=%d", "hi", 42) != "x=hi y=42"   { print("[FAIL] %s %d"); exit("1") }
    if format("%d%% done", 50)       != "50% done"     { print("[FAIL] %%"); exit("1") }
    if format("no verbs")            != "no verbs"     { print("[FAIL] no verbs"); exit("1") }
    let n = 7
    if format("sq=%d", n * n)        != "sq=49"        { print("[FAIL] expr arg"); exit("1") }
    if format("%d-%d-%d", 1, 2, 3)   != "1-2-3"        { print("[FAIL] 3 args"); exit("1") }
    if format("%s!", "hi")           != "hi!"          { print("[FAIL] trailing piece"); exit("1") }
    print("[PASS] format/printf compile-time expansion (%s %d %% multi-arg)")
}
