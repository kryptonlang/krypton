import "k:objk_process_macos"

func check(actual, expected, label) {
    if actual != expected {
        print("[FAIL] " + label + ": [" + actual + "]")
        exit("1")
    }
}

just run {
    let pool = newPool()
    let args = okProcessArgs()
    doProcessArg(args, "a b")
    check(okRunArgvCaptured("/bin/echo", args), "0\na b\n", "argv spaces")
    args = okProcessArgs()
    doProcessArg(args, "%s")
    doProcessArg(args, "' ; $HOME $(echo INJECTED)\n")
    check(okRunArgvCaptured("/usr/bin/printf", args), "0\n' ; $HOME $(echo INJECTED)\n", "literal argv")
    args = okProcessArgs()
    doProcessArg(args, "<%s>")
    doProcessArg(args, "")
    check(okRunArgvCaptured("/usr/bin/printf", args), "0\n<>", "empty argument")
    check(okRunArgvCaptured("/usr/bin/false", okProcessArgs()), "1\n", "nonzero exit")
    check(okRunCaptured("printf OUT; printf ERR >&2; exit 7"), "7\nOUTERR", "combined output and status")
    check(okRunCaptured("kill -TERM $$"), "143\n", "signal status")
    check(getLine(okRunCaptured("printf '\\377'"), 0), "-2", "invalid UTF-8 output")
    check(getLine(okRunArgvCaptured("/no/such/objk-executable", okProcessArgs()), 0), "-1", "launch failure")
    let large = okRunCaptured("/usr/bin/awk 'BEGIN {for(i=0;i<20000;i++) printf \"abcdefgh\"}'")
    check(len(large), 160002, "drain beyond pipe capacity")
    drainPool(pool)
    print("[PASS] Objective-K process capture")
}
