import "k:objk"

func check(label, expected, actual) {
    if expected != actual { print("FAIL " + label); exit(1) }
    print("PASS " + label)
}
just run {
    let app = okApp()
    let win = okWindow(app, "Objective-K scroll layout regression", 640, 480)
    check("content width uses NSRect ABI", 640, okViewWidth(msg(win, "contentView")))
    check("content height uses NSRect ABI", 480, okViewHeight(msg(win, "contentView")))
    let a = allocInit("NSTableView")
    let b = allocInit("NSTableView")
    check("same foreign handle", 1, okSameHandle(a, a))
    check("different same-class handles", 0, okSameHandle(a, b))
    check("nil handles", 1, okSameHandle(0, 0))
    let text = okTextView(win, 0, 0, 100, 100)
    let scroll = msg(text, "enclosingScrollView")
    check("scroll layout succeeds", "1", okScrollFrame(text, 20, 30, 420, 240))
    check("scroll container width", 420, okViewWidth(scroll))
    check("scroll container height", 240, okViewHeight(scroll))
    okScrollHidden(text, 1)
    check("container hidden", 1, msg(scroll, "isHidden"))
    okScrollHidden(text, 0)
    check("container restored", 0, msg(scroll, "isHidden"))
    let field = okField(win, 0, 0, 100, 24)
    check("non-scroll view rejected", "0", okScrollFrame(field, 0, 0, 10, 10))
    check("non-scroll hide rejected", "0", okScrollHidden(field, 1))
    print("PASS Objective-K scroll layout")
}
