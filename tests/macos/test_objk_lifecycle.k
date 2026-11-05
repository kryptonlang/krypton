import "k:okui"

func check(actual, expected, name) {
    if actual != expected { print("[FAIL] " + name); exit("1") }
}
func rejectClose(win) { okSet(win, "test.decision", nsString("veto")); emit 0 }
func allowClose(win) { okSet(win, "test.decision", nsString("allow")); emit 1 }
func closed(win) { okSet(win, "test.closed", nsString("closed")); emit 0 }
func closedAgain(win) { okSet(win, "test.closed", nsString("rebound")); emit 0 }
func detachClose(win) { okWindowOnClose(win, 0); emit 0 }
func opened(app, path) { okSet(app, "test.path", nsString(path)); emit 1 }
func rejectOpen(app, path) { emit 0 }
func reopenApp(app, visible) { okSet(app, "test.visible", okNumber(visible)); emit 0 }
func detachOpen(app, path) { okAppOnOpenFile(app, 0); emit 1 }

func testApplication(app) {
    let watchers = msg(cls("NSHashTable"), "weakObjectsHashTable")
    let scope = okAutoreleasePool()
    check(okAppOnOpenFile(0, funcptr(opened)), "0", "nil app")
    check(okAppOnOpenFile(app, 0), "1", "empty detach")
    let foreign = allocInit("NSObject")
    msg_1(app, "setDelegate:", foreign)
    check(okAppOnOpenFile(app, funcptr(opened)), "0", "foreign app delegate")
    check(msg_1(msg(app, "delegate"), "isEqual:", foreign), 1, "preserve app delegate")
    msg_1(app, "setDelegate:", 0)
    msg(foreign, "release")
    check(okAppOnOpenFile(app, funcptr(opened)), "1", "open registration")
    check(okAppOnReopen(app, funcptr(reopenApp)), "1", "reopen registration")
    let proxy = msg(app, "delegate")
    msg_1(watchers, "addObject:", proxy)
    check(msg_2(proxy, "application:openFile:", app, nsString("/tmp/a b 'quoted'.k")), 1, "open result")
    check(nsToStr(okGet(app, "test.path")), "/tmp/a b 'quoted'.k", "literal path")
    check(msg_2(proxy, "applicationShouldHandleReopen:hasVisibleWindows:", app, 1), 0, "reopen result")
    check(okNumberValue(okGet(app, "test.visible")), 1, "visible true")
    msg_2(proxy, "applicationShouldHandleReopen:hasVisibleWindows:", app, 0)
    check(okNumberValue(okGet(app, "test.visible")), 0, "visible false")
    okAppOnOpenFile(app, funcptr(rejectOpen))
    check(msg_2(proxy, "application:openFile:", app, nsString("/tmp/no")), 0, "open rebinding")
    okAppOnOpenFile(app, 0)
    check(msg_2(proxy, "application:openFile:", app, nsString("/tmp/no")), 0, "missing open rejects")
    check(msg_2(proxy, "applicationShouldHandleReopen:hasVisibleWindows:", app, 0), 0, "reopen survives detach")
    okAppOnReopen(app, 0)
    check(msg(app, "delegate"), 0, "app delegate released")
    okDrainPool(scope)
    check(msg(msg(watchers, "allObjects"), "count"), 0, "app proxy deallocated")
    scope = okAutoreleasePool()
    okAppOnOpenFile(app, funcptr(detachOpen))
    msg_1(watchers, "addObject:", msg(app, "delegate"))
    check(msg_2(msg(app, "delegate"), "application:openFile:", app, nsString("/tmp/detach")), 1, "self detach result")
    check(msg(app, "delegate"), 0, "self detach releases app delegate")
    okDrainPool(scope)
    check(msg(msg(watchers, "allObjects"), "count"), 0, "self-detached app proxy deallocated")
    emit 0
}

func testWindows(app) {
    if msg(msg(cls("NSScreen"), "screens"), "count") == 0 {
        print("[SKIP] window lifecycle: no display")
        emit 0
    }
    let first = okWindow(app, "Lifecycle first", 320, 200)
    let second = okWindow(app, "Lifecycle second", 320, 200)
    msg_1(first, "setReleasedWhenClosed:", 0)
    msg_1(second, "setReleasedWhenClosed:", 0)
    let watchers = msg(cls("NSHashTable"), "weakObjectsHashTable")
    let scope = okAutoreleasePool()
    check(okWindowShouldClose(0, funcptr(allowClose)), "0", "nil window")
    check(okWindowOnClose(first, funcptr(closed)), "1", "close registration")
    msg_1(watchers, "addObject:", msg(first, "delegate"))
    check(okWindowShouldClose(first, funcptr(rejectClose)), "1", "veto registration")
    check(okWindowOnClose(second, funcptr(closedAgain)), "1", "second close registration")
    msg_1(first, "performClose:", 0)
    check(nsToStr(okGet(first, "test.decision")), "veto", "native close veto")
    check(okGet(first, "test.closed"), 0, "veto prevents close notification")
    check(okGet(second, "test.closed"), 0, "second window isolated")
    okWindowShouldClose(first, funcptr(allowClose))
    msg_1(first, "performClose:", 0)
    check(nsToStr(okGet(first, "test.decision")), "allow", "native close allowed")
    check(nsToStr(okGet(first, "test.closed")), "closed", "native close notification")
    okWindowOnClose(first, 0)
    check(msg(first, "delegate") != 0, 1, "veto hook survives close detach")
    okWindowShouldClose(first, 0)
    check(msg(first, "delegate"), 0, "all window hooks detached")
    okDrainPool(scope)
    check(msg(msg(watchers, "allObjects"), "count"), 0, "window proxy deallocated")
    scope = okAutoreleasePool()
    let foreign = allocInit("NSObject")
    msg_1(first, "setDelegate:", foreign)
    check(okWindowOnClose(first, funcptr(closed)), "0", "foreign window delegate")
    check(msg_1(msg(first, "delegate"), "isEqual:", foreign), 1, "preserve window delegate")
    msg_1(first, "setDelegate:", 0)
    msg(foreign, "release")
    msg_1(second, "performClose:", 0)
    check(nsToStr(okGet(second, "test.closed")), "rebound", "second native close")
    okWindowOnClose(second, 0)
    okWindowOnClose(second, funcptr(detachClose))
    msg_1(watchers, "addObject:", msg(second, "delegate"))
    let notification = msg_3(cls("NSNotification"), "notificationWithName:object:userInfo:", nsString("NSWindowWillCloseNotification"), second, 0)
    msg_1(msg(second, "delegate"), "windowWillClose:", notification)
    check(msg(second, "delegate"), 0, "self detach releases window delegate")
    okDrainPool(scope)
    check(msg(msg(watchers, "allObjects"), "count"), 0, "self-detached window proxy deallocated")
    msg(first, "release")
    msg(second, "release")
    emit 0
}

just run {
    let pool = okAutoreleasePool()
    let app = okSharedApp()
    testApplication(app)
    testWindows(app)
    okDrainPool(pool)
    print("[PASS] AppKit window and application lifecycle")
}
