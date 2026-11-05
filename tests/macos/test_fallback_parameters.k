import "k:dict"
import "k:option"
import "k:result"

func check(actual, expected) {
    if actual != expected {
        print("[FAIL] fallback parameter: expected " + expected + ", got " + actual)
        exit(1)
    }
}
just run {
    check(dictgetk("name,found", "name", "fallback"), "found")
    check(dictgetk("name,found", "missing", "fallback"), "fallback")
    check(dictgetk("", "", "fallback"), "fallback")
    check(dictsetdefaultk("", "missing", "fallback"), "fallback")
    check(dictsetdefaultupd("", "missing", "fallback"), "missing,fallback")
    check(dictsetdefaultupd("", "", "fallback"), ",fallback")
    check(indictk("", ""), 0)
    check(dictpopk("", "missing", "fallback"), "fallback")
    check(optUnwrapOr("none", "fallback"), "fallback")
    check(optUnwrapOr("some:found", "fallback"), "found")
    check(unwrapOr("err:missing", "fallback"), "fallback")
    check(unwrapOr("ok:found", "fallback"), "found")
    print("[PASS] fallback parameters use nonreserved names")
}
