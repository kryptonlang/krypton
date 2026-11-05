import "k:okui"

func check(actual, expected, name) {
    if actual != expected { print("[FAIL] " + name); exit("1") }
}
func rowCount(self, command, table) { emit 3 }
func cellText(self, command, table, column, row) { emit nsString("item") }
func single(table) { okSet(table, "test.action", nsString("single")); emit 0 }
func double(table) { okSet(table, "test.action", nsString("double")); emit 0 }
func rawAction(self, command, sender) { emit 0 }
func fire(table, selectorName) {
    msg_2(msg(table, "target"), "performSelector:withObject:", msg(table, selectorName), table)
    emit 0
}
func nativeInteger(object, key) { emit msg(msg_1(object, "valueForKey:", nsString(key)), "intValue") }

func testFrames() {
    if msg(msg(cls("NSScreen"), "screens"), "count") == 0 {
        print("[SKIP] frame persistence: no display")
        emit 0
    }
    let app = okSharedApp()
    let win = okWindow(app, "Frame test", 360, 240)
    msg_1(win, "setReleasedWhenClosed:", 0)
    let key = "KryptonFrameProbe_" + trim(exec("uuidgen"))
    let width = msgRectWidth(win, "frame")
    check(okFrameSave(win, key), "1", "save frame")
    msg_d2(win, "setContentSize:", 600, 400)
    check(okFrameRestore(win, key), 1, "restore frame")
    check(msgRectWidth(win, "frame"), width, "restored geometry")
    check(okFrameRestore(win, key + "missing"), 0, "unknown saved frame")
    msg_1(cls("NSWindow"), "removeFrameUsingName:", nsString(key))
    msg(win, "close")
    msg(win, "release")
    emit 0
}

just run {
    let pool = okAutoreleasePool()
    let table = okTable(0, 0, 0, 400, 200)
    check(msg(msg(table, "enclosingScrollView"), "hasHorizontalScroller"), 1, "horizontal scrolling")
    let column = okColumn(table, "c0", "Name", 160)
    check(msg(table, "numberOfColumns"), 1, "reuse default column")
    check(nsToStr(msg(column, "title")), "Name", "column title")
    check(nativeInteger(column, "width"), 160, "column width")
    let detail = okColumn(table, "detail", "Detail", 120)
    check(msg(table, "numberOfColumns"), 2, "add column")
    check(okColWidth(table, "detail", 140), "1", "resize column")
    check(nativeInteger(detail, "width"), 140, "resized width")
    check(okColWidth(table, "missing", 100), "0", "unknown column")
    check(okColumn(table, "", "bad", 100), 0, "empty identifier")
    check(okRowHeight(table, 24), "1", "row height")
    check(nativeInteger(table, "rowHeight"), 24, "row height value")
    check(okRowHeight(table, 0), "0", "reject zero height")
    check(okOnClick(table, funcptr(single)), "1", "single registration")
    check(okOnDoubleClick(table, funcptr(double)), "1", "double registration")
    fire(table, "action")
    check(nsToStr(okGet(table, "test.action")), "single", "single action")
    fire(table, "doubleAction")
    check(nsToStr(okGet(table, "test.action")), "double", "double action")
    okOnClick(table, 0)
    check(msg(table, "action"), 0, "single detached")
    fire(table, "doubleAction")
    check(nsToStr(okGet(table, "test.action")), "double", "double independent")
    okOnDoubleClick(table, 0)
    check(msg(table, "target"), 0, "all actions detached")
    okClick(table, funcptr(rawAction))
    check(okOnDoubleClick(table, funcptr(double)), "0", "preserve external action")

    let menu = allocInit("NSMenu")
    okMenuSelector(menu, "Visible", "", "description")
    let item = msg_1(menu, "itemWithTitle:", nsString("Visible"))
    check(okMenuCheck(menu, "Visible", 1), "1", "check menu")
    check(msg(item, "state"), 1, "menu checked")
    okMenuCheck(menu, "Visible", 0)
    check(msg(item, "state"), 0, "menu unchecked")
    check(okMenuEnabled(menu, "Visible", 0), "1", "disable menu")
    msg(menu, "update")
    check(msg(item, "isEnabled"), 0, "disabled after validation")
    check(msg(menu, "autoenablesItems"), 0, "manual menu validation")
    check(okMenuEnabled(menu, "Missing", 1), "0", "missing menu item")

    let temp = trim(exec("mktemp -d /tmp/objk-controls.XXXXXX"))
    if temp == "" { print("[FAIL] temporary folder"); exit("1") }
    let path = temp + "/preview.png"
    let image = okImage(16)
    okImageBegin(image)
    okColorSet(okRGB(30, 100, 150))
    okFillRect(0, 0, 16, 16)
    okImageEnd(image)
    check(okImagePNG(image, path), 1, "image fixture")
    let view = okImageView(0, 0, 0, 32, 32)
    check(okImageFromFile(view, path), "1", "load image")
    let previous = msg(view, "image")
    check(msg(previous, "isValid"), 1, "image decoded")
    check(okImageFromFile(view, temp + "/missing.png"), "0", "missing image")
    check(msg_1(msg(view, "image"), "isEqual:", previous), 1, "failure preserves image")

    testFrames()
    msg(image, "release")
    msg(view, "release")
    msg(menu, "release")
    shellRun("/bin/rm -rf " + temp)
    okDrainPool(pool)
    print("[PASS] AppKit columns, actions, menus, images, and frames")
}
