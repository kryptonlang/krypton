import "k:okui"

func showText(field) {
    let label = okGet(field, "tutorial.label")
    okSetText(label, okText(field))
    emit 0
}

just run {
    let pool = okAutoreleasePool()
    let app = okApp()
    let win = okWindow(app, "Objective-K Live Field", 460, 160)
    let bar = okMenuBar(app)
    let menu = okMenuAdd(bar, "Live Field")
    okMenuSelector(menu, "Quit", "q", "terminate:")
    let edit = okMenuAdd(bar, "Edit")
    okMenuSelector(edit, "Cut", "x", "cut:")
    okMenuSelector(edit, "Copy", "c", "copy:")
    okMenuSelector(edit, "Paste", "v", "paste:")
    okMenuSelector(edit, "Select All", "a", "selectAll:")
    let field = okField(win, 20, 92, 420, 28)
    okPlaceholder(field, "Text")
    let label = okLabel(win, "", 20, 44, 420, 28)
    okSet(field, "tutorial.label", label)
    if okFieldOnChange(field, funcptr(showText)) == "0" {
        printErr("Cannot register live field handler\n")
        exit("1")
    }
    okShow(win, app)
    okMakeFirstResponder(win, field)
    okRun(app)
    okDrainPool(pool)
}
