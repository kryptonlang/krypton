// Guards foreign-call ABI and cfCount branch offsets without starting AppKit.
import "k:objc"
import "head:objc"

just run {
    let pool = newPool()
    if pool == 0 { print("[FAIL] imported autorelease-pool class"); exit("1") }
    let nsObj = objc_getClass(NSObject_cls)
    if class_getName(nsObj) != "NSObject" { print("[FAIL] objc_getClass NSObject"); exit("1") }
    let nsStrCls = objc_getClass(NSString_cls)
    if class_getName(nsStrCls) != "NSString" { print("[FAIL] objc_getClass NSString"); exit("1") }

    let ns = nsString("hello-objc")
    if msg(ns, sel_UTF8String) != "hello-objc" { print("[FAIL] NSString UTF8String roundtrip"); exit("1") }

    if msg(ns, "length") != 10 { print("[FAIL] NSString length"); exit("1") }

    drainPool(pool)
    print("[PASS] objc smoke: imported constants + getClass + msgSend")
}
