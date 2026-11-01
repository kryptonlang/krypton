import "k:objc"

just run {
    let pool = newPool()
    let text = nsString("Objective-K UTF-8 text")
    if nsToStr(text) != "Objective-K UTF-8 text" {
        print("[FAIL] NSString conversion")
        exit("1")
    }
    let number = msg_1(cls("NSNumber"), "numberWithInt:", 42)
    if nsToStr(number) != "42" || nsToStr(0) != "" {
        print("[FAIL] description or nil conversion")
        exit("1")
    }
    drainPool(pool)
    print("[PASS] Objective-C object text conversion")
}
