import "k:okui"

func tableRows(self, command, table) {
    emit okArrayCount(okGet(table, "demo.visible"))
}

func tableCell(self, command, table, column, row) {
    let item = okArrayGet(okGet(table, "demo.visible"), row)
    if nsToStr(msg(column, "identifier")) == "kind" {
        let name = nsToStr(item)
        if contains(name, "compiler") { emit nsString("Compiler") }
        if contains(name, "runtime") { emit nsString("Runtime") }
        if contains(name, "adapter") { emit nsString("Adapter") }
        emit nsString("Application")
    }
    emit item
}

func selectedName(table) {
    let selected = okSelection(table)
    if okSelectionCount(selected) == 0 { emit "" }
    emit nsToStr(okArrayGet(okGet(table, "demo.visible"), okSelectionAt(selected, 0)))
}
func clicked(table) { okSetText(okGet(table, "demo.status"), "Selected: " + selectedName(table)); emit 0 }
func doubleClicked(table) { okSetText(okGet(table, "demo.status"), "Activated: " + selectedName(table)); emit 0 }
func windowClosed(win) { okFrameSave(win, "KryptonTableLab.frame"); emit 0 }
func reopenLab(app, visible) {
    if visible == 0 {
        let win = okGet(app, "demo.window")
        okShow(win, app)
        okSetText(okGet(win, "demo.status"), "Window reopened")
    }
    emit 1
}
func quitLab(self, command, sender) {
    let app = okSharedApp()
    okFrameSave(okGet(app, "demo.window"), "KryptonTableLab.frame")
    okQuit(app)
    emit 0
}

func filterRows(field) {
    let table = okGet(field, "demo.table")
    let items = okGet(table, "demo.items")
    let visible = okArray()
    let queryText = okText(field)
    let query = nsString(queryText)
    let i = 0
    while i < okArrayCount(items) {
        let item = okArrayGet(items, i)
        if queryText == "" || msg_1(item, "localizedCaseInsensitiveContainsString:", query) != 0 {
            okArrayAdd(visible, item)
        }
        i += 1
    }
    okSelectNone(table)
    okSet(table, "demo.visible", visible)
    okReload(table)
    okSetText(okGet(table, "demo.status"), "Items: " + okArrayCount(visible))
    emit 0
}

func tableKey(table, event) {
    let code = okKeyCode(event)
    if code == 53 {
        okSelectNone(table)
        okSetText(okGet(table, "demo.status"), "Items: " + okArrayCount(okGet(table, "demo.visible")))
        emit 1
    }
    if code == 36 {
        let selection = okSelection(table)
        if okSelectionCount(selection) > 0 {
            let row = okSelectionAt(selection, 0)
            okSetText(okGet(table, "demo.status"), nsToStr(okArrayGet(okGet(table, "demo.visible"), row)))
        }
        emit 1
    }
    emit 0
}

just run {
    let pool = okAutoreleasePool()
    let app = okApp()
    let win = okWindow(app, "Objective-K Table Lab", 680, 460)
    msg_1(win, "setReleasedWhenClosed:", 0)
    okMinSize(win, 480, 320)
    okSet(app, "demo.window", win)
    okFrameRestore(win, "KryptonTableLab.frame")
    okWindowOnClose(win, funcptr(windowClosed))
    okAppOnReopen(app, funcptr(reopenLab))
    let bar = okMenuBar(app)
    let menu = okMenuAdd(bar, "Table Lab")
    okMenuAction(menu, "Quit", "q", funcptr(quitLab))
    let edit = okMenuAdd(bar, "Edit")
    okMenuSelector(edit, "Cut", "x", "cut:")
    okMenuSelector(edit, "Copy", "c", "copy:")
    okMenuSelector(edit, "Paste", "v", "paste:")
    okMenuSelector(edit, "Select All", "a", "selectAll:")
    let field = okField(win, 20, 412, 640, 28)
    okPlaceholder(field, "Filter")
    okAutoresizing(field, 10)
    let table = okTable(win, 20, 68, 640, 326)
    okMultiSelect(table, 1)
    okColumn(table, "c0", "Component", 440)
    okColumn(table, "kind", "Kind", 160)
    okRowHeight(table, 24)
    let scroll = msg(table, "enclosingScrollView")
    okAutoresizing(scroll, 18)
    let status = okLabel(win, "Items: 6", 20, 24, 640, 24)
    okSet(win, "demo.status", status)
    let items = okArray()
    okArrayAdd(items, nsString("AppKit adapter"))
    okArrayAdd(items, nsString("Code Brain editor"))
    okArrayAdd(items, nsString("Krypton compiler"))
    okArrayAdd(items, nsString("Objective-K runtime"))
    okArrayAdd(items, nsString("Stem terminal"))
    okArrayAdd(items, nsString("Synapse browser"))
    okSet(table, "demo.items", items)
    okSet(table, "demo.visible", items)
    okSet(table, "demo.status", status)
    okSet(field, "demo.table", table)
    let sourceClass = okClass("KryptonTableLabSource")
    okMethod(sourceClass, "numberOfRowsInTableView:", funcptr(tableRows), "q@:@")
    okMethod(sourceClass, "tableView:objectValueForTableColumn:row:", funcptr(tableCell), "@@:@@q")
    okRegister(sourceClass)
    let source = okNew(sourceClass)
    okDataSource(table, source)
    msg(source, "release")
    okOnKeyDown(table, funcptr(tableKey))
    okOnClick(table, funcptr(clicked))
    okOnDoubleClick(table, funcptr(doubleClicked))
    okFieldOnChange(field, funcptr(filterRows))
    okReload(table)
    okShow(win, app)
    okMakeFirstResponder(win, field)
    okRun(app)
    okDrainPool(pool)
}
