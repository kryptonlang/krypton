import "k:objk"

func first(self, command, sender) { chocSetAssocKey(sender, "probe", nsString("first")) }
func second(self, command, sender) { chocSetAssocKey(sender, "probe", nsString("second")) }
func third(self, command, sender) { chocSetAssocKey(sender, "probe", nsString("third")) }
func answer(self, command) { emit 42 }

func checkButton(button, expected) {
    msg_2(msg(button, "target"), "performSelector:withObject:", msg(button, "action"), button)
    if nsToStr(chocGetAssocKey(button, "probe")) != expected {
        print("[FAIL] callback " + expected)
        exit("1")
    }
}

just run {
    let pool = newPool()
    let a = allocInit("NSButton")
    let b = allocInit("NSButton")
    let c = allocInit("NSButton")
    okClick(a, funcptr(first))
    okClick(b, funcptr(second))
    okClick(c, funcptr(third))
    checkButton(a, "first")
    checkButton(b, "second")
    let seg = allocInit("NSSegmentedControl")
    if okSegAdd(seg, "List") != 0 || okSegAdd(seg, "Grid") != 1 {
        print("[FAIL] segment add")
        exit("1")
    }
    okSegSelect(seg, 1)
    if okSegIndex(seg) != 1 || nsToStr(msg_1(seg, "labelForSegment:", 0)) != "List" {
        print("[FAIL] segment state")
        exit("1")
    }
    if okSegSelect(seg, 9) != "0" || okSegIndex(seg) != 1 {
        print("[FAIL] segment bounds")
        exit("1")
    }
    okSegOnChange(seg, funcptr(second))
    checkButton(seg, "second")
    checkButton(c, "third")
    okClick(a, funcptr(third))
    checkButton(a, "third")
    checkButton(b, "second")
    let klass = okClass("KryptonDuplicateClassProbe")
    let pending = okClass("KryptonDuplicateClassProbe")
    if msg_1(msg_1(cls("NSValue"), "valueWithPointer:", klass), "isEqualToValue:", msg_1(cls("NSValue"), "valueWithPointer:", pending)) == 0 {
        print("[FAIL] duplicate pending class")
        exit("1")
    }
    if okViewClass("KryptonDuplicateClassProbe") != 0 { print("[FAIL] pending parent conflict"); exit("1") }
    if okMethod(klass, "answer", funcptr(answer), "q@:") != "1" { print("[FAIL] add method"); exit("1") }
    okRegister(klass)
    let again = okClass("KryptonDuplicateClassProbe")
    if again != klass || okRegister(again) != "1" { print("[FAIL] duplicate class"); exit("1") }
    if okMethod(again, "answer", funcptr(answer), "q@:") != "0" { print("[FAIL] duplicate method"); exit("1") }
    if okRegister(0) != "0" || okMethod(0, "answer", funcptr(answer), "q@:") != "0" {
        print("[FAIL] nil class guard")
        exit("1")
    }
    let object = msg(klass, "new")
    if msg(object, "answer") != 42 { print("[FAIL] preserved method"); exit("1") }
    let viewClass = okViewClass("KryptonDuplicateViewProbe")
    okRegister(viewClass)
    if okViewClass("KryptonDuplicateViewProbe") != viewClass { print("[FAIL] duplicate view class"); exit("1") }
    msg(object, "release")
    msg(a, "release")
    msg(b, "release")
    msg(c, "release")
    msg(seg, "release")
    drainPool(pool)
    print("[PASS] callback isolation and class guards")
}
