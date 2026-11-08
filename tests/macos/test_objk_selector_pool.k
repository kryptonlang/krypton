import "k:cocoa"

func check(value, name) {
    if value != 1 { print("[FAIL] " + name); exit(1) }
}

just run {
    let outer = newPool()
    let app = cocoaInit()
    let win = cocoaWindow(app, "Objective-K dispatch probe", 320, 180)
    msg_1(win, "setReleasedWhenClosed:", 0)
    let field = cocoaTextField(win, 10, 30, 280, 30)
    cocoaFinishLaunching(app)
    let iteration = 0
    while iteration < 100 {
        let pool = newPool()
        let builder = sbNew()
        sbAppend(builder, "setString")
        sbAppend(builder, "Value:")
        let method = sbToString(builder)
        let handle = sel(method)
        check(msg_1(field, "respondsToSelector:", handle), "composed selector")
        let text = "value " + iteration
        msg_1(field, method, nsString(text))
        check(nsToStr(msg(field, "stringValue")) == text, "dynamic message")
        let keyBuilder = sbNew()
        sbAppend(keyBuilder, "objk.selector.probe.")
        sbAppend(keyBuilder, "" + iteration)
        cocoaSetAssocKey(app, sbToString(keyBuilder), nsString(text))
        sbAppend(keyBuilder, ".changed")
        cocoaPumpEvents(app)
        msg(app, "updateWindows")
        drainPool(pool)
        gcCollect()
        check(msg_1(field, "respondsToSelector:", handle), "selector after collection")
        let key = "objk.selector.probe." + iteration
        check(nsToStr(cocoaGetAssocKey(app, key)) == text, "retained association")
        cocoaSetAssocKey(app, key, 0)
        check(msgRectWidth(field, "frame") == 280, "rectangle width ABI")
        check(msgRectHeight(field, "frame") == 30, "rectangle height ABI")
        iteration += 1
    }
    msg(win, "close")
    msg(win, "release")
    drainPool(outer)
    print("[PASS] dynamic selectors, retained associations, rectangle ABI and frame pools")
}
