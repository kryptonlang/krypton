import "k:okui"

func check(actual, expected, name) {
    if actual != expected { print("[FAIL] " + name); exit("1") }
}
func rows(self, command, table) { emit 5 }
func cell(self, command, table, column, row) { emit nsString("row") }
func keysA(table, event) { okSet(table, "test.key", okNumber(11)); emit 1 }
func keysB(table, event) { okSet(table, "test.key", okNumber(22)); emit 1 }
func changed(field) {
    let count = okNumberValue(okGet(field, "test.count")) + 1
    okSet(field, "test.count", okNumber(count))
    okSet(field, "test.text", nsString(okText(field)))
    emit 0
}
func changedAgain(field) { okSet(field, "test.text", nsString("rebound")); emit 0 }
func notify(field) {
    let center = msg(cls("NSNotificationCenter"), "defaultCenter")
    msg_2(center, "postNotificationName:object:", nsString("NSControlTextDidChangeNotification"), field)
    emit 0
}

just run {
    let pool = okAutoreleasePool()
    let sourceClass = okClass("KryptonTableEventsSource")
    okMethod(sourceClass, "numberOfRowsInTableView:", funcptr(rows), "q@:@")
    okMethod(sourceClass, "tableView:objectValueForTableColumn:row:", funcptr(cell), "@@:@@q")
    okRegister(sourceClass)
    let source = okNew(sourceClass)
    let table = okTable(0, 0, 0, 320, 200)
    let other = okTable(0, 0, 0, 320, 200)
    okDataSource(table, source)
    okDataSource(other, source)
    msg(source, "release")
    okReload(table)
    okReload(other)
    okMultiSelect(table, 1)
    check(msg(table, "numberOfRows"), 5, "retained data source")
    let selection = okSelectionNew()
    okSelectionAdd(selection, 1)
    okSelectionAdd(selection, 3)
    check(okSelect(table, selection), "1", "select rows")
    let snapshot = okSelection(table)
    check(okSelectionCount(snapshot), 2, "selection count")
    check(okSelectionAdd(snapshot, 2), "0", "immutable snapshot")
    check(okSelectionAt(snapshot, 0), 1, "first row")
    check(okSelectionAt(snapshot, 1), 3, "second row")
    check(okSelectionAt(snapshot, 2), "", "out of range index")
    check(okSelectRow(table, 4, 1), "1", "extend selection")
    check(okSelectionCount(okSelection(table)), 3, "extended selection count")
    check(okSelectionCount(snapshot), 2, "selection snapshot")
    check(okSelectRow(table, 9, 0), "0", "reject invalid row")
    check(okSelectRow(table, -1, 0), "0", "reject negative row")
    check(okSelectionAt(snapshot, -1), "", "reject negative offset")
    check(okSelectionCount(okSelection(table)), 3, "invalid preserves selection")
    check(okScrollTo(table, 9), "0", "invalid scroll")
    okSelectNone(table)
    check(okSelectionCount(okSelection(table)), 0, "clear selection")
    okSelectAll(table)
    check(okSelectionCount(okSelection(table)), 5, "select all")
    check(okOnKeyDown(table, funcptr(keysA)), "1", "register keys")
    check(okOnKeyDown(other, funcptr(keysB)), "1", "independent keys")
    msg_1(table, "keyDown:", 0)
    msg_1(other, "keyDown:", 0)
    check(okNumberValue(okGet(table, "test.key")), 11, "first key handler")
    check(okNumberValue(okGet(other, "test.key")), 22, "second key handler")
    okOnKeyDown(table, funcptr(keysB))
    msg_1(table, "keyDown:", 0)
    check(okNumberValue(okGet(table, "test.key")), 22, "rebind keys")
    okOnKeyDown(table, 0)
    check(okOnKeyDown(0, funcptr(keysA)), "0", "reject nil key target")
    check(okSelectAll(0), "0", "reject nil selection target")
    let field = allocInit("NSTextField")
    check(okFieldOnChange(field, funcptr(changed)), "1", "register changes")
    okSetText(field, "filter")
    check(okNumberValue(okGet(field, "test.count")), 0, "programmatic change not user event")
    notify(field)
    check(nsToStr(okGet(field, "test.text")), "filter", "native field change")
    check(okNumberValue(okGet(field, "test.count")), 1, "one notification")
    let owned = msg(field, "delegate")
    okFieldOnChange(field, funcptr(changedAgain))
    check(msg_1(msg(field, "delegate"), "isEqual:", owned), 1, "reuse owned delegate")
    notify(field)
    check(nsToStr(okGet(field, "test.text")), "rebound", "rebound change")
    okFieldOnChange(field, 0)
    check(msg(field, "delegate"), 0, "detach delegate")
    let external = allocInit("NSObject")
    msg_1(field, "setDelegate:", external)
    check(okFieldOnChange(field, funcptr(changed)), "0", "preserve external delegate")
    check(msg_1(msg(field, "delegate"), "isEqual:", external), 1, "external delegate unchanged")
    msg_1(field, "setDelegate:", 0)
    msg(external, "release")
    msg(field, "release")
    okDataSource(table, 0)
    okDataSource(other, 0)
    okDrainPool(pool)
    print("[PASS] native table selection, keys, and field changes")
}
