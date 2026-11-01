import "k:os"

func check(actual, expected, label) {
    if actual != expected {
        print("[FAIL] " + label + ": [" + actual + "]")
        exit("1")
    }
}

just run {
    check(exec("printf 'hi\\n'; exit 7"), "hi\n", "exec preserves stdout")
    check(shellRun("exit 7"), "7", "shellRun nonzero")
    check(shellRun("true"), "0", "shellRun success")
    check(ossystemk("false"), "1", "os.system failure")
    check(ossystemk("true"), "0", "os.system success")
    print("[PASS] process status")
}
