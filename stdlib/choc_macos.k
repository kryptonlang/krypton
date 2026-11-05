module choc_macos

import "k:objc"

func chocInit() {
    let app = msg(cls("NSApplication"), "sharedApplication")
    msg_1(app, "setActivationPolicy:", 0)        // NSApplicationActivationPolicyRegular
    msg_1(app, "activateIgnoringOtherApps:", 1)
    emit app
}

func chocSharedApp() { emit msg(cls("NSApplication"), "sharedApplication") }
func chocRun(app)  { msg(app, "run")             emit "0" }
func chocQuit(app) { msg_1(app, "terminate:", app)  emit "1" }

func chocWindow(app, title, w, h) {
    let mask = 15                                 // Titled|Closable|Miniaturizable|Resizable
    let raw = msg(cls("NSWindow"), "alloc")
    let win = msg_rect(raw, "initWithContentRect:styleMask:backing:defer:",
        0, 0, w, h, mask, 2, 0)                   // backing = NSBackingStoreBuffered (2)
    msg_1(win, "setTitle:", nsString(title))
    emit win
}

func chocShow(win, app) { msg_1(win, "makeKeyAndOrderFront:", app)  emit "1" }
func chocTransparentTitlebar(win) { msg_1(win, "setTitlebarAppearsTransparent:", 1)  emit "1" }

func chocButton(win, label, x, y, w, h) {
    let raw = msg(cls("NSButton"), "alloc")
    let btn = msg_frame(raw, "initWithFrame:", x, y, w, h)
    msg_1(btn, "setTitle:", nsString(label))
    _addToContentView(win, btn)
    emit btn
}

func chocCheckbox(win, label, x, y, w, h) {
    let raw = msg(cls("NSButton"), "alloc")
    let cb = msg_frame(raw, "initWithFrame:", x, y, w, h)
    msg_1(cb, "setTitle:", nsString(label))
    msg_1(cb, "setButtonType:", 3)        // NSButtonTypeSwitch
    _addToContentView(win, cb)
    emit cb
}

func chocTextField(win, x, y, w, h) {
    let raw = msg(cls("NSTextField"), "alloc")
    let tf = msg_frame(raw, "initWithFrame:", x, y, w, h)
    msg_1(tf, "setEditable:", 1)
    msg_1(tf, "setSelectable:", 1)
    msg_1(tf, "setBezeled:", 1)            // visible, focusable input box
    msg_1(tf, "setDrawsBackground:", 1)
    _addToContentView(win, tf)
    emit tf
}

func chocSecureTextField(win, x, y, w, h) {
    let raw = msg(cls("NSSecureTextField"), "alloc")
    let tf = msg_frame(raw, "initWithFrame:", x, y, w, h)
    msg_1(tf, "setEditable:", 1)
    msg_1(tf, "setSelectable:", 1)
    msg_1(tf, "setBezeled:", 1)
    msg_1(tf, "setDrawsBackground:", 1)
    _addToContentView(win, tf)
    emit tf
}

func chocLabel(win, text, x, y, w, h) {
    let raw = msg(cls("NSTextField"), "alloc")
    let lbl = msg_frame(raw, "initWithFrame:", x, y, w, h)
    msg_1(lbl, "setStringValue:", nsString(text))
    msg_1(lbl, "setEditable:", 0)
    _addToContentView(win, lbl)
    emit lbl
}

func chocPlainLabel(win, text, x, y, w, h) {
    let raw = msg(cls("NSTextField"), "alloc")
    let lbl = msg_frame(raw, "initWithFrame:", x, y, w, h)
    msg_1(lbl, "setStringValue:", nsString(text))
    msg_1(lbl, "setEditable:", 0)
    msg_1(lbl, "setSelectable:", 0)
    msg_1(lbl, "setBezeled:", 0)
    msg_1(lbl, "setBordered:", 0)
    msg_1(lbl, "setDrawsBackground:", 0)
    _addToContentView(win, lbl)
    emit lbl
}

func chocProgress(win, x, y, w, h) {
    let p = msg_frame(msg(cls("NSProgressIndicator"), "alloc"), "initWithFrame:", x, y, w, h)
    msg_1(p, "setIndeterminate:", 0)
    msg_d1(p, "setMinValue:", 0)
    msg_d1(p, "setMaxValue:", 100)
    _addToContentView(win, p)
    emit p
}

func chocProgressSpinner(win, x, y, w, h) {
    let p = msg_frame(msg(cls("NSProgressIndicator"), "alloc"), "initWithFrame:", x, y, w, h)
    msg_1(p, "setIndeterminate:", 1)
    msg_1(p, "setStyle:", 1)              // spinning
    _addToContentView(win, p)
    emit p
}

func chocSlider(win, x, y, w, h, min, max, value) {
    let s = msg_frame(msg(cls("NSSlider"), "alloc"), "initWithFrame:", x, y, w, h)
    msg_d1(s, "setMinValue:", min)
    msg_d1(s, "setMaxValue:", max)
    msg_d1(s, "setDoubleValue:", value)
    _addToContentView(win, s)
    emit s
}

func chocComboBox(win, x, y, w, h) {
    let c = msg_frame(msg(cls("NSComboBox"), "alloc"), "initWithFrame:", x, y, w, h)
    msg_1(c, "setEditable:", 1)
    msg_1(c, "setCompletes:", 1)
    _addToContentView(win, c)
    emit c
}

func chocSetText(control, text) { msg_1(control, "setStringValue:", nsString(text))  emit "1" }

func chocGetText(control) {
    let s = msg(control, "stringValue")
    emit msg(s, "UTF8String")
}

func chocSetEnabled(control, enabled) { msg_1(control, "setEnabled:", enabled)  emit "1" }
func chocSetHidden(view, hidden)      { msg_1(view, "setHidden:", hidden)       emit "1" }
func chocSetFrame(view, x, y, w, h)   { msg_frame(view, "setFrame:", x, y, w, h) emit "1" }
func chocSetTitle(obj, title)         { msg_1(obj, "setTitle:", nsString(title)) emit "1" }
func chocSetToolTip(view, text)       { msg_1(view, "setToolTip:", nsString(text)) emit "1" }
func chocSetEditable(control, editable) { msg_1(control, "setEditable:", editable) emit "1" }
func chocSetSelectable(control, selectable) { msg_1(control, "setSelectable:", selectable) emit "1" }
func chocSetBordered(control, bordered) { msg_1(control, "setBordered:", bordered) emit "1" }
func chocSetBezeled(control, bezeled) { msg_1(control, "setBezeled:", bezeled) emit "1" }
func chocSetDrawsBackground(control, draws) { msg_1(control, "setDrawsBackground:", draws) emit "1" }
func chocSetPlaceholder(control, text) { msg_1(control, "setPlaceholderString:", nsString(text)) emit "1" }
func chocSetAutoresizing(view, mask)  { msg_1(view, "setAutoresizingMask:", mask) emit "1" }
func chocRemove(view)                 { msg(view, "removeFromSuperview") emit "1" }
func chocSetWindowMinSize(win, w, h)  { msg_d2(win, "setMinSize:", w, h) emit "1" }
func chocState(control)               { emit msg(control, "state") }
func chocSetState(control, state)     { msg_1(control, "setState:", state) emit "1" }
func chocSetProgress(p, value)        { msg_d1(p, "setDoubleValue:", value) emit "1" }
func chocStartProgress(p)             { msg_1(p, "startAnimation:", p) emit "1" }
func chocStopProgress(p)              { msg_1(p, "stopAnimation:", p) emit "1" }
func chocComboAdd(combo, text)        { msg_1(combo, "addItemWithObjectValue:", nsString(text)) emit "1" }
func chocComboSelect(combo, index)    { msg_1(combo, "selectItemAtIndex:", index) emit "1" }
func chocComboSelected(combo)         { emit msg(combo, "indexOfSelectedItem") }
func chocComboSelectedText(combo) {
    let s = msg(combo, "objectValueOfSelectedItem")
    if s == 0 { emit "" }
    emit msg(s, "UTF8String")
}

func chocAlert(title, message) {
    let alert = allocInit("NSAlert")
    msg_1(alert, "setMessageText:", nsString(title))
    msg_1(alert, "setInformativeText:", nsString(message))
    msg(alert, "runModal")
    emit "1"
}

// IMP callbacks receive (self, _cmd, sender) in x0..x2, matching K's ABI.
// Use a distinct key per handler: pointer-to-string conversion loses identity.
func chocOnClickKeyed(control, keyName, fnPtr) {
    if control == 0 || fnPtr == 0 { printErr("Objective-K: click needs a control and callback\n"); emit "0" }
    let nm = "KryptonObjkCB_" + _classSafe(keyName)
    let c = objc_lookUpClass(nm)
    if c == 0 {
        c = objc_allocateClassPair(cls("NSObject"), nm, 0)
        if c == 0 { printErr("Objective-K: cannot allocate callback class '" + nm + "'\n"); emit "0" }
        if chocClassAddMethod(c, "objk_dispatch:", fnPtr, "v@:@") == "0" { emit "0" }
        objc_registerClassPair(c)
    }
    let target = msg(msg(c, "alloc"), "init")
    msg_1(control, "setTarget:", target)
    msg_1(control, "setAction:", sel("objk_dispatch:"))
    chocSetAssocKey(control, "kr.objk.clickTarget", target)
    msg(target, "release")
    emit "1"
}
// Registration is main-thread-only, like the AppKit controls it modifies.
func chocOnClick(control, fnPtr) {
    if control == 0 || fnPtr == 0 { printErr("Objective-K: click needs a control and callback\n"); emit "0" }
    let owner = cls("NSObject")
    let counter = chocNumberVal(chocGetAssocKey(owner, "kr.objk.clickSequence")) + 1
    while objc_lookUpClass("KryptonObjkCB_auto_" + counter) != 0 { counter += 1 }
    chocSetAssocKey(owner, "kr.objk.clickSequence", chocNumber(counter))
    emit chocOnClickKeyed(control, "auto_" + counter, fnPtr)
}

// Intern selectors as association keys; separate string literals can differ.
func chocSetAssoc(control, value) {
    objc_setAssociatedObject(control, sel("kr.assoc"), value, 1)  // RETAIN_NONATOMIC
    emit "1"
}

func chocGetAssoc(control) {
    emit objc_getAssociatedObject(control, sel("kr.assoc"))
}
func chocSetAssocKey(control, key, value) { objc_setAssociatedObject(control, sel(key), value, 1)  emit "1" }
func chocGetAssocKey(control, key)        { emit objc_getAssociatedObject(control, sel(key)) }

func chocArray()             { emit msg(cls("NSMutableArray"), "array") }
func chocArrayAdd(arr, obj)  { msg_1(arr, "addObject:", obj)  emit "1" }
func chocArrayCount(arr)     { emit msg(arr, "count") }
func chocArrayGet(arr, i)    { emit msg_1(arr, "objectAtIndex:", i) }
func chocArraySet(arr, i, o) { msg_2(arr, "replaceObjectAtIndex:withObject:", i, o)  emit "1" }
func chocArrayRemove(arr, i) { msg_1(arr, "removeObjectAtIndex:", i)  emit "1" }
func chocNumber(n)           { emit msg_1(cls("NSNumber"), "numberWithInt:", n) }
func chocNumberVal(num)      { emit msg(num, "intValue") }

func chocSegmented(win, x, y, w, h) {
    let seg = msg_frame(msg(cls("NSSegmentedControl"), "alloc"), "initWithFrame:", x, y, w, h)
    _addToContentView(win, seg)
    emit seg
}
func chocSegCount(seg, n)        { msg_1(seg, "setSegmentCount:", n)  emit "1" }
func chocSegLabel(seg, lbl, i)   { msg_2(seg, "setLabel:forSegment:", nsString(lbl), i)  emit "1" }
func chocSegSelect(seg, i)       { msg_1(seg, "setSelectedSegment:", i)  emit "1" }
func chocSegSelected(seg)        { emit msg(seg, "selectedSegment") }
func chocSegOnChange(seg, fnPtr) { emit chocOnClick(seg, fnPtr) }

// Return the text view; attach its scroll view to the window.
func chocScrollText(win, x, y, w, h) {
    let sv = msg_frame(msg(cls("NSScrollView"), "alloc"), "initWithFrame:", x, y, w, h)
    msg_1(sv, "setHasVerticalScroller:", 1)
    msg_1(sv, "setBorderType:", 2)                 // NSBezelBorder
    let tv = msg_frame(msg(cls("NSTextView"), "alloc"), "initWithFrame:", 0, 0, w, h)
    msg_1(tv, "setRichText:", 0)
    msg_1(sv, "setDocumentView:", tv)
    msg_1(sv, "setAutoresizingMask:", 18)   // width+height sizable -> follow the window
    _addToContentView(win, sv)
    emit tv
}
func chocTVSetString(tv, s) { msg_1(tv, "setString:", nsString(s))  emit "1" }
func chocTVGetString(tv)    { emit msg(msg(tv, "string"), "UTF8String") }
// Disable soft-wrap: the grid / source defines line breaks (terminal behaviour).
func chocTVNoWrap(tv) {
    let tc = msg(tv, "textContainer")
    msg_1(tc, "setWidthTracksTextView:", 0)
    msg_d2(tc, "setSize:", 1000000, 1000000)
    msg_1(tv, "setHorizontallyResizable:", 1)
    emit "1"
}
// Append without rebuilding the whole document (for streaming output, e.g. a pty).
func chocTVAppend(tv, s) {
    let astr = msg_1(msg(cls("NSAttributedString"), "alloc"), "initWithString:", nsString(s))
    msg_1(msg(tv, "textStorage"), "appendAttributedString:", astr)
    msg_1(tv, "scrollToEndOfDocument:", 0)
    emit "1"
}

// Syntax highlighting: colour a [loc, loc+len) range of the text view's storage.
// NSRange is a 16-byte struct (location, length) → passed as two GP args, so
// addAttribute:value:range: is a plain msg_4. Attribute keys use their stable
// runtime string values ("NSColor" = foreground, "NSFont" = font).
func chocTVColorRange(tv, color, loc, len) {
    let ts = msg(tv, "textStorage")
    let total = msg(ts, "length")
    if loc >= total { emit "1" }
    let l = len
    if loc + l > total { l = total - loc }
    msg_4(ts, "addAttribute:value:range:", nsString("NSColor"), color, loc, l)
    emit "1"
}
func chocTVFontRange(tv, font, loc, len) {
    let ts = msg(tv, "textStorage")
    let total = msg(ts, "length")
    if loc >= total { emit "1" }
    let l = len
    if loc + l > total { l = total - loc }
    msg_4(ts, "addAttribute:value:range:", nsString("NSFont"), font, loc, l)
    emit "1"
}
func chocTVLength(tv) { emit msg(msg(tv, "textStorage"), "length") }

// Set a delegate whose textStorageDidProcessEditing: (a Krypton func) re-colours
// on every edit — the canonical highlighting hook. These operate on the storage
// the delegate receives (notif object); guard on chocTSEditedChars so re-adding
// attributes (which itself fires the delegate) does not recurse.
func chocTVSetStorageDelegate(tv, d) { msg_1(msg(tv, "textStorage"), "setDelegate:", d)  emit "1" }
func chocTSString(ts)     { emit msg(msg(ts, "string"), "UTF8String") }
func chocTSLength(ts)     { emit msg(ts, "length") }
func chocTSEditedChars(ts){ emit bitAnd(msg(ts, "editedMask"), 2) }   // 2 = NSTextStorageEditedCharacters (1 = attributes)
func chocTSClearColor(ts) {
    msg_3(ts, "removeAttribute:range:", nsString("NSColor"), 0, msg(ts, "length"))
    emit "1"
}
func chocTSColorRange(ts, color, loc, len) {
    let total = msg(ts, "length")
    if loc >= total { emit "1" }
    let l = len
    if loc + l > total { l = total - loc }
    msg_4(ts, "addAttribute:value:range:", nsString("NSColor"), color, loc, l)
    emit "1"
}

func chocColorNamed(name)        { emit msg(cls("NSColor"), name) }
func chocSystemWindowBg()        { emit chocColorNamed("windowBackgroundColor") }
func chocSystemText()            { emit chocColorNamed("textColor") }
func chocSystemSecondaryText()   { emit chocColorNamed("secondaryLabelColor") }
func chocSystemTextBg()          { emit chocColorNamed("textBackgroundColor") }
// True NSColor from 0-255 RGB (exact 256-colour/truecolor; named colours are the basic 16).
func chocRGB(r, g, b) { emit msg_rgb(cls("NSColor"), "colorWithRed:green:blue:alpha:", r, g, b) }
func chocSetBg(view, color)      { msg_1(view, "setBackgroundColor:", color)  emit "1" }
func chocSetTextColor(tv, color) { msg_1(tv, "setTextColor:", color)          emit "1" }
func chocSetWindowBg(win, color) { msg_1(win, "setBackgroundColor:", color)   emit "1" }

func chocChooseFolder(title) {
    let panel = msg(cls("NSOpenPanel"), "openPanel")
    msg_1(panel, "setTitle:", nsString(title))
    msg_1(panel, "setCanChooseFiles:", 0)
    msg_1(panel, "setCanChooseDirectories:", 1)
    msg_1(panel, "setAllowsMultipleSelection:", 0)
    if msg(panel, "runModal") != 1 { emit "" }
    let url = msg(panel, "URL")
    if url == 0 { emit "" }
    emit msg(msg(url, "path"), "UTF8String")
}

func chocChooseFile(title) {
    let panel = msg(cls("NSOpenPanel"), "openPanel")
    msg_1(panel, "setTitle:", nsString(title))
    msg_1(panel, "setCanChooseFiles:", 1)
    msg_1(panel, "setCanChooseDirectories:", 0)
    msg_1(panel, "setAllowsMultipleSelection:", 0)
    if msg(panel, "runModal") != 1 { emit "" }
    let url = msg(panel, "URL")
    if url == 0 { emit "" }
    emit msg(msg(url, "path"), "UTF8String")
}

func chocSaveFile(title, defaultName) {
    let panel = msg(cls("NSSavePanel"), "savePanel")
    msg_1(panel, "setTitle:", nsString(title))
    if len(defaultName) > 0 { msg_1(panel, "setNameFieldStringValue:", nsString(defaultName)) }
    if msg(panel, "runModal") != 1 { emit "" }
    let url = msg(panel, "URL")
    if url == 0 { emit "" }
    emit msg(msg(url, "path"), "UTF8String")
}

func chocBundledExecutable(name) {
    let bundle = msg(cls("NSBundle"), "mainBundle")
    let path = msg_1(bundle, "pathForAuxiliaryExecutable:", nsString(name))
    if path == 0 { emit "" }
    emit msg(path, "UTF8String")
}

func chocBundledResource(name) {
    let bundle = msg(cls("NSBundle"), "mainBundle")
    let path = msg_2(bundle, "pathForResource:ofType:", nsString(name), 0)
    if path == 0 { emit "" }
    emit msg(path, "UTF8String")
}

func chocTemporaryDirectory() {
    let url = msg(msg(cls("NSFileManager"), "defaultManager"), "temporaryDirectory")
    if url == 0 { emit "" }
    emit msg(msg(url, "path"), "UTF8String")
}

func chocClipboardText() {
    let pb = msg(cls("NSPasteboard"), "generalPasteboard")
    let s = msg_1(pb, "stringForType:", nsString("public.utf8-plain-text"))
    if s == 0 { emit "" }
    emit msg(s, "UTF8String")
}

func chocSetClipboardText(text) {
    let pb = msg(cls("NSPasteboard"), "generalPasteboard")
    msg(pb, "clearContents")
    msg_2(pb, "setString:forType:", nsString(text), nsString("public.utf8-plain-text"))
    emit "1"
}

func chocDefaultsGet(key) {
    let s = msg_1(msg(cls("NSUserDefaults"), "standardUserDefaults"), "stringForKey:", nsString(key))
    if s == 0 { emit "" }
    emit msg(s, "UTF8String")
}

func chocDefaultsSet(key, value) {
    let d = msg(cls("NSUserDefaults"), "standardUserDefaults")
    msg_2(d, "setObject:forKey:", nsString(value), nsString(key))
    msg(d, "synchronize")
    emit "1"
}

func chocDefaultsRemove(key) {
    let d = msg(cls("NSUserDefaults"), "standardUserDefaults")
    msg_1(d, "removeObjectForKey:", nsString(key))
    msg(d, "synchronize")
    emit "1"
}

func chocURL(url)       { emit msg_1(cls("NSURL"), "URLWithString:", nsString(url)) }
func chocFileURL(path)  { emit msg_1(cls("NSURL"), "fileURLWithPath:", nsString(path)) }

func chocOpenURL(url) {
    let u = chocURL(url)
    if u == 0 { emit "0" }
    emit msg_1(msg(cls("NSWorkspace"), "sharedWorkspace"), "openURL:", u)
}

func chocOpenPath(path) {
    let u = chocFileURL(path)
    if u == 0 { emit "0" }
    emit msg_1(msg(cls("NSWorkspace"), "sharedWorkspace"), "openURL:", u)
}

func chocRevealPath(path) {
    let u = chocFileURL(path)
    if u == 0 { emit "0" }
    let arr = chocArray()
    chocArrayAdd(arr, u)
    msg_1(msg(cls("NSWorkspace"), "sharedWorkspace"), "activateFileViewerSelectingURLs:", arr)
    emit "1"
}

func chocAppearanceName(obj) {
    let a = msg(obj, "effectiveAppearance")
    if a == 0 { emit "" }
    let n = msg(a, "name")
    if n == 0 { emit "" }
    emit msg(n, "UTF8String")
}

func chocIsDark(obj) {
    if indexOf(chocAppearanceName(obj), "Dark") >= 0 { emit 1 }
    emit 0
}

func chocSetAppearance(obj, name) {
    let a = msg_1(cls("NSAppearance"), "appearanceNamed:", nsString(name))
    if a == 0 { emit "0" }
    msg_1(obj, "setAppearance:", a)
    emit "1"
}

// [NSFont userFixedPitchFontOfSize:n] — monospaced (size in pt, int is fine).
func chocMonoFont(size)     { emit msg_d1(cls("NSFont"), "userFixedPitchFontOfSize:", size) }
// Refamily a font (keeps size/metrics) — e.g. to a Nerd Font for powerline glyphs.
// Returns `base` unchanged if the family isn't installed. No double arg needed.
func chocFontFamily(base, family) {
    emit msg_2(msg(cls("NSFontManager"), "sharedFontManager"), "convertFont:toFamily:", base, nsString(family))
}
func chocSetFont(view, font){ msg_1(view, "setFont:", font)  emit "1" }

// Build an Obj-C class at runtime whose methods are Krypton funcs (used as
// IMPs). Lets a data source / delegate be written in pure Krypton — every
// method takes (self, _cmd, …) and returns via x0/d0.
//   let c = chocClassNew("MyDataSource")
//   chocClassAddMethod(c, "numberOfRowsInTableView:", funcptr(nrows), "q@:@")
//   chocClassRegister(c)
//   let inst = chocNew(c)
func _chocPendingClasses() {
    let owner = cls("NSObject")
    let registry = chocGetAssocKey(owner, "kr.objk.pendingClasses")
    if registry == 0 {
        registry = msg(cls("NSMutableDictionary"), "dictionary")
        chocSetAssocKey(owner, "kr.objk.pendingClasses", registry)
    }
    emit registry
}
func _chocClassNew(name, parentName) {
    if name == "" { printErr("Objective-K: class name is empty\n"); emit 0 }
    let existing = objc_lookUpClass(name)
    if existing != 0 {
        printErr("Objective-K: reusing registered class '" + name + "'\n")
        emit existing
    }
    let registry = _chocPendingClasses()
    let record = msg_1(registry, "objectForKey:", nsString(name))
    if record != 0 {
        let parent = msg_1(record, "objectForKey:", nsString("parent"))
        if msg_1(parent, "isEqualToString:", nsString(parentName)) == 0 {
            printErr("Objective-K: pending class '" + name + "' has another parent\n")
            emit 0
        }
        printErr("Objective-K: reusing pending class '" + name + "'\n")
        emit msg(msg_1(record, "objectForKey:", nsString("class")), "pointerValue")
    }
    let c = objc_allocateClassPair(cls(parentName), name, 0)
    if c == 0 { printErr("Objective-K: cannot allocate class '" + name + "'\n"); emit 0 }
    record = msg(cls("NSMutableDictionary"), "dictionary")
    msg_2(record, "setObject:forKey:", nsString(parentName), nsString("parent"))
    msg_2(record, "setObject:forKey:", msg_1(cls("NSValue"), "valueWithPointer:", c), nsString("class"))
    msg_2(registry, "setObject:forKey:", record, nsString(name))
    emit c
}
func chocClassNew(name) { emit _chocClassNew(name, "NSObject") }
// Subclass NSView (for a custom-drawn view: add a drawRect: method whose IMP is a
// Krypton func). The drawRect: dirtyRect arrives in d0..d3 (FP regs) and is simply
// ignored by the Krypton handler (it reads x0=self, x1=_cmd).
func chocViewClassNew(name) { emit _chocClassNew(name, "NSView") }
// Fill the current colour into a rect (call [color set] first). NSBezierPath fillRect:
// takes only the NSRect -> d0..d3, so it's msg_frame.
func chocFillRect(x, y, w, h)      { msg_frame(cls("NSBezierPath"), "fillRect:", x, y, w, h)  emit "1" }
func chocColorSet(color)           { msg(color, "set")  emit "1" }
// Build a text-attributes dict {font, color} for drawing strings.
func chocTextAttrs(font, color) {
    let d = msg(cls("NSMutableDictionary"), "dictionary")
    msg_2(d, "setObject:forKey:", font, nsString("NSFont"))
    msg_2(d, "setObject:forKey:", color, nsString("NSColor"))
    emit d
}
func chocSetButtonTextColor(btn, color) {
    let title = msg(btn, "title")
    let attrs = chocTextAttrs(msg(btn, "font"), color)
    let astr = msg_2(msg(cls("NSAttributedString"), "alloc"), "initWithString:attributes:", title, attrs)
    msg_1(btn, "setAttributedTitle:", astr)
    emit "1"
}
// Draw a string into a rect with the given attributes (use inside drawRect:).
func chocDrawText(str, x, y, w, h, attrs) {
    msg_rectp(nsString(str), "drawInRect:withAttributes:", x, y, w, h, attrs)
    emit "1"
}
// Instantiate a custom view with a frame and add it to the window.
func chocCustomView(win, c, x, y, w, h) {
    let v = msg_frame(msg(c, "alloc"), "initWithFrame:", x, y, w, h)
    msg_1(v, "setAutoresizingMask:", 18)   // width+height sizable -> follow the window
    _addToContentView(win, v)
    emit v
}
func chocNeedsDisplay(v)           { msg_1(v, "setNeedsDisplay:", 1)  emit "1" }
func chocMakeFirstResponder(win, v){ msg_1(win, "makeFirstResponder:", v)  emit "1" }

// Fires `actionSel` on `target` every `ms` milliseconds (ms/1000 -> TimeInterval).
func chocTimer(target, actionSel, ms) {
    emit msg_timer(cls("NSTimer"), "scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:",
        ms, target, actionSel, 0, 1)
}

// Use instead of chocRun when you must interleave native work (e.g. reading a
// pty) with event handling in the MAIN flow — doing such work inside a timer/
// action callback can fault. chocFinishLaunching once, then loop:
//   chocPumpEvents(app)  // drain pending events
//   <your work>
//   sleepUs(0, 8000)
func chocFinishLaunching(app) { msg(app, "finishLaunching")  msg_1(app, "activateIgnoringOtherApps:", 1)  emit "1" }
// Dispatch one pending event (non-blocking); returns 1 if one was handled, else 0.
func chocPumpEvent(app) {
    let ev = msg_4(app, "nextEventMatchingMask:untilDate:inMode:dequeue:",
        0 - 1, 0, nsString("kCFRunLoopDefaultMode"), 1)
    if ev == 0 { emit 0 }
    // key-down with a modifier: let the main menu claim ⌘-shortcuts first
    // ([NSApp run] does this automatically; the manual pump must do it itself).
    if msg(ev, "type") == 10 {
        let mm = msg(app, "mainMenu")
        if mm != 0 { if msg_1(mm, "performKeyEquivalent:", ev) == 1 { emit 1 } }
    }
    msg_1(app, "sendEvent:", ev)
    emit 1
}
func chocPumpEvents(app) {
    while chocPumpEvent(app) == 1 { }
    emit "1"
}
func chocClassAddMethod(c, selName, fnPtr, types) {
    if c == 0 || fnPtr == 0 {
        printErr("Objective-K: cannot add method '" + selName + "' to a nil class or callback\n")
        emit "0"
    }
    if class_addMethod(c, sel(selName), fnPtr, types) == 0 {
        printErr("Objective-K: cannot add method '" + selName + "' to class '" + class_getName(c) + "'\n")
        emit "0"
    }
    emit "1"
}
func chocClassRegister(c) {
    if c == 0 { printErr("Objective-K: cannot register nil class\n"); emit "0" }
    let name = class_getName(c)
    let existing = objc_lookUpClass(name)
    let value = msg_1(cls("NSValue"), "valueWithPointer:", c)
    if existing != 0 {
        if msg_1(value, "isEqualToValue:", msg_1(cls("NSValue"), "valueWithPointer:", existing)) != 0 {
            printErr("Objective-K: class '" + name + "' already registered\n")
            emit "1"
        }
        printErr("Objective-K: another class is registered as '" + name + "'\n")
        emit "0"
    }
    let registry = _chocPendingClasses()
    let record = msg_1(registry, "objectForKey:", nsString(name))
    if record != 0 {
        if msg_1(value, "isEqualToValue:", msg_1(record, "objectForKey:", nsString("class"))) == 0 {
            printErr("Objective-K: another class is pending as '" + name + "'\n")
            emit "0"
        }
    }
    objc_registerClassPair(c)
    msg_1(registry, "removeObjectForKey:", nsString(name))
    emit "1"
}
func chocNew(c)                    { emit msg(msg(c, "alloc"), "init") }

func _chocTableKeyDown(self, command, event) {
    let handlerBox = chocGetAssocKey(self, "kr.table.keyCallback")
    if handlerBox != 0 {
        let pointer = msg(handlerBox, "pointerValue")
        if callPtr(pointer, self, event) != 0 { emit 0 }
    }
    let parent = msg_1(cls("NSTableView"), "instanceMethodForSelector:", command)
    callPtr(parent, self, command, event)
    emit 0
}

func _chocTableClick(self, command, sender) {
    let handlerBox = chocGetAssocKey(self, "kr.table.clickCallback")
    if handlerBox != 0 { callPtr(msg(handlerBox, "pointerValue"), self) }
    emit 0
}

func _chocTableDoubleClick(self, command, sender) {
    let handlerBox = chocGetAssocKey(self, "kr.table.doubleCallback")
    if handlerBox != 0 { callPtr(msg(handlerBox, "pointerValue"), self) }
    emit 0
}

func _chocTableClass() {
    let name = "KryptonObjkTableView"
    let c = objc_lookUpClass(name)
    if c != 0 { emit c }
    c = objc_allocateClassPair(cls("NSTableView"), name, 0)
    if c == 0 { printErr("Objective-K: cannot allocate table class\n"); emit 0 }
    if chocClassAddMethod(c, "keyDown:", funcptr(_chocTableKeyDown), "v@:@") == "0" { emit 0 }
    if chocClassAddMethod(c, "krTableClick:", funcptr(_chocTableClick), "v@:@") == "0" { emit 0 }
    if chocClassAddMethod(c, "krTableDoubleClick:", funcptr(_chocTableDoubleClick), "v@:@") == "0" { emit 0 }
    chocClassRegister(c)
    emit c
}

func chocTable(win, x, y, w, h) {
    let tableClass = _chocTableClass()
    if tableClass == 0 { emit 0 }
    let sv = msg_frame(msg(cls("NSScrollView"), "alloc"), "initWithFrame:", x, y, w, h)
    msg_1(sv, "setHasVerticalScroller:", 1)
    msg_1(sv, "setHasHorizontalScroller:", 1)
    msg_1(sv, "setAutohidesScrollers:", 1)
    msg_1(sv, "setBorderType:", 0)             // no bezel border
    msg_1(sv, "setFocusRingType:", 1)          // no blue focus ring
    let tbl = msg_frame(msg(tableClass, "alloc"), "initWithFrame:", 0, 0, w, h)
    msg_1(tbl, "setFocusRingType:", 1)
    let col = msg_1(msg(cls("NSTableColumn"), "alloc"), "initWithIdentifier:", nsString("c0"))
    msg_d1(col, "setWidth:", w)
    msg_1(tbl, "addTableColumn:", col)
    msg(col, "release")
    msg_1(sv, "setDocumentView:", tbl)
    _addToContentView(win, sv)
    emit tbl
}
func chocSetDataSource(table, ds) {
    if table == 0 { emit "0" }
    msg_1(table, "setDataSource:", ds)
    chocSetAssocKey(table, "kr.table.dataSource", ds)
    emit "1"
}
func chocReload(table) {
    if table == 0 { emit "0" }
    msg(table, "reloadData")
    emit "1"
}

func chocTableOnKeyDown(table, fnPtr) {
    if table == 0 { emit "0" }
    if msg_1(table, "isKindOfClass:", objc_lookUpClass("KryptonObjkTableView")) == 0 { emit "0" }
    let boxed = 0
    if fnPtr != 0 { boxed = msg_1(cls("NSValue"), "valueWithPointer:", fnPtr) }
    chocSetAssocKey(table, "kr.table.keyCallback", boxed)
    emit "1"
}

func chocTableOnClick(table, fnPtr, doubleClick) {
    if table == 0 { emit "0" }
    if msg_1(table, "isKindOfClass:", objc_lookUpClass("KryptonObjkTableView")) == 0 { emit "0" }
    let target = msg(table, "target")
    if target != 0 {
        if msg_1(target, "isEqual:", table) == 0 {
            printErr("Objective-K: table already has another action target\n")
            emit "0"
        }
    }
    let key = "kr.table.clickCallback"
    let action = "krTableClick:"
    if doubleClick != 0 { key = "kr.table.doubleCallback"; action = "krTableDoubleClick:" }
    let boxed = 0
    if fnPtr != 0 { boxed = msg_1(cls("NSValue"), "valueWithPointer:", fnPtr) }
    chocSetAssocKey(table, key, boxed)
    let selector = 0
    if fnPtr != 0 { selector = sel(action) }
    if doubleClick != 0 { msg_1(table, "setDoubleAction:", selector) }
    else { msg_1(table, "setAction:", selector) }
    if chocGetAssocKey(table, "kr.table.clickCallback") == 0 && chocGetAssocKey(table, "kr.table.doubleCallback") == 0 {
        msg_1(table, "setTarget:", 0)
    } else { msg_1(table, "setTarget:", table) }
    emit "1"
}

func chocColumn(table, identifier, title, width) {
    if table == 0 || identifier == "" || width <= 0 { emit 0 }
    let column = msg_1(table, "tableColumnWithIdentifier:", nsString(identifier))
    if column == 0 {
        column = msg_1(msg(cls("NSTableColumn"), "alloc"), "initWithIdentifier:", nsString(identifier))
        msg_1(table, "addTableColumn:", column)
        msg(column, "release")
    }
    msg_1(column, "setTitle:", nsString(title))
    msg_d1(column, "setWidth:", width)
    emit column
}
func chocColWidth(table, identifier, width) {
    if table == 0 || width <= 0 { emit "0" }
    let column = msg_1(table, "tableColumnWithIdentifier:", nsString(identifier))
    if column == 0 { emit "0" }
    msg_d1(column, "setWidth:", width)
    emit "1"
}
func chocRowHeight(table, height) {
    if table == 0 || height <= 0 { emit "0" }
    msg_d1(table, "setRowHeight:", height)
    emit "1"
}

func chocMenuCheck(menu, title, checked) {
    if menu == 0 { emit "0" }
    let item = msg_1(menu, "itemWithTitle:", nsString(title))
    if item == 0 { emit "0" }
    let state = 0
    if checked != 0 { state = 1 }
    msg_1(item, "setState:", state)
    emit "1"
}
func chocMenuEnabled(menu, title, enabled) {
    if menu == 0 { emit "0" }
    let item = msg_1(menu, "itemWithTitle:", nsString(title))
    if item == 0 { emit "0" }
    msg_1(menu, "setAutoenablesItems:", 0)
    msg_1(item, "setEnabled:", enabled)
    emit "1"
}
func chocImageView(win, x, y, w, h) {
    let view = msg_frame(msg(cls("NSImageView"), "alloc"), "initWithFrame:", x, y, w, h)
    msg_1(view, "setImageScaling:", 3)
    _addToContentView(win, view)
    emit view
}
func chocImageFromFile(view, path) {
    if view == 0 || path == "" { emit "0" }
    let image = msg_1(msg(cls("NSImage"), "alloc"), "initWithContentsOfFile:", nsString(path))
    if image == 0 { emit "0" }
    msg_1(view, "setImage:", image)
    msg(image, "release")
    emit "1"
}
func chocFrameSave(win, key) {
    if win == 0 || key == "" { emit "0" }
    if msg(msg(cls("NSScreen"), "screens"), "count") == 0 { emit "0" }
    msg_1(win, "saveFrameUsingName:", nsString(key))
    emit "1"
}
func chocFrameRestore(win, key) {
    if win == 0 || key == "" { emit "0" }
    if msg(msg(cls("NSScreen"), "screens"), "count") == 0 { emit "0" }
    emit msg_2(win, "setFrameUsingName:force:", nsString(key), 1)
}

func chocSelectionNew() { emit msg(cls("NSMutableIndexSet"), "indexSet") }
func chocSelection(table) {
    let snapshot = msg(msg(table, "selectedRowIndexes"), "copy")
    emit msg(snapshot, "autorelease")
}
func chocSelectionCount(rows) { emit msg(rows, "count") }
func chocSelectionAdd(rows, row) {
    if rows == 0 || row < 0 { emit "0" }
    if msg_1(rows, "respondsToSelector:", sel("addIndex:")) == 0 { emit "0" }
    msg_1(rows, "addIndex:", row)
    emit "1"
}
func chocSelectionAt(rows, offset) {
    if offset < 0 || offset >= msg(rows, "count") { emit "" }
    let row = msg(rows, "firstIndex")
    let i = 0
    while i < offset {
        row = msg_1(rows, "indexGreaterThanIndex:", row)
        i += 1
    }
    emit row
}
func chocSelect(table, rows, extend) {
    if table == 0 || rows == 0 { emit "0" }
    if msg(rows, "count") > 0 {
        if msg(rows, "lastIndex") >= msg(table, "numberOfRows") { emit "0" }
    }
    msg_2(table, "selectRowIndexes:byExtendingSelection:", rows, extend)
    emit "1"
}
func chocSelectRow(table, row, extend) {
    if table == 0 || row < 0 || row >= msg(table, "numberOfRows") { emit "0" }
    let rows = msg_1(cls("NSIndexSet"), "indexSetWithIndex:", row)
    emit chocSelect(table, rows, extend)
}
func chocScrollTo(table, row) {
    if table == 0 || row < 0 || row >= msg(table, "numberOfRows") { emit "0" }
    msg_1(table, "scrollRowToVisible:", row)
    emit "1"
}

func _chocFieldChanged(self, command, notification) {
    let field = msg(notification, "object")
    let handlerBox = chocGetAssocKey(field, "kr.field.changeCallback")
    if handlerBox != 0 { callPtr(msg(handlerBox, "pointerValue"), field) }
    emit 0
}
func chocFieldOnChange(field, fnPtr) {
    if field == 0 { emit "0" }
    let owned = chocGetAssocKey(field, "kr.field.changeDelegate")
    let current = msg(field, "delegate")
    if current != 0 {
        if owned == 0 || msg_1(current, "isEqual:", owned) == 0 {
            printErr("Objective-K: field already has another delegate\n")
            emit "0"
        }
    }
    if fnPtr == 0 {
        msg_1(field, "setDelegate:", 0)
        chocSetAssocKey(field, "kr.field.changeDelegate", 0)
        chocSetAssocKey(field, "kr.field.changeCallback", 0)
        emit "1"
    }
    let name = "KryptonObjkFieldChanges"
    let c = objc_lookUpClass(name)
    if c == 0 {
        c = chocClassNew(name)
        if c == 0 { emit "0" }
        if chocClassAddMethod(c, "controlTextDidChange:", funcptr(_chocFieldChanged), "v@:@") == "0" { emit "0" }
        chocClassRegister(c)
    }
    if owned == 0 {
        owned = msg(c, "new")
        chocSetAssocKey(field, "kr.field.changeDelegate", owned)
        msg(owned, "release")
    }
    chocSetAssocKey(field, "kr.field.changeCallback", msg_1(cls("NSValue"), "valueWithPointer:", fnPtr))
    msg_1(field, "setDelegate:", owned)
    emit "1"
}

func _chocWindowShouldClose(self, command, win) {
    let handlerBox = chocGetAssocKey(self, "kr.window.shouldClose")
    if handlerBox == 0 { emit 1 }
    msg(self, "retain")
    let result = callPtr(msg(handlerBox, "pointerValue"), win)
    msg(self, "release")
    if result == 1 { emit 1 }
    emit 0
}
func _chocWindowWillClose(self, command, notification) {
    let handlerBox = chocGetAssocKey(self, "kr.window.willClose")
    if handlerBox != 0 {
        msg(self, "retain")
        callPtr(msg(handlerBox, "pointerValue"), msg(notification, "object"))
        msg(self, "release")
    }
    emit 0
}
func _chocAppOpenFile(self, command, app, filename) {
    let handlerBox = chocGetAssocKey(self, "kr.app.openFile")
    if handlerBox == 0 { emit 0 }
    msg(self, "retain")
    let result = callPtr(msg(handlerBox, "pointerValue"), app, nsToStr(filename))
    msg(self, "release")
    if result == 1 { emit 1 }
    emit 0
}
func _chocAppReopen(self, command, app, visible) {
    let handlerBox = chocGetAssocKey(self, "kr.app.reopen")
    if handlerBox == 0 { emit 1 }
    msg(self, "retain")
    let result = callPtr(msg(handlerBox, "pointerValue"), app, visible)
    msg(self, "release")
    if result == 1 { emit 1 }
    emit 0
}
func _chocLifecycleClass(windowKind) {
    let name = "KryptonObjkAppLifecycle"
    if windowKind != 0 { name = "KryptonObjkWindowLifecycle" }
    let c = objc_lookUpClass(name)
    if c != 0 { emit c }
    c = chocClassNew(name)
    if c == 0 { emit 0 }
    if windowKind != 0 {
        if chocClassAddMethod(c, "windowShouldClose:", funcptr(_chocWindowShouldClose), "B@:@") == "0" { emit 0 }
        if chocClassAddMethod(c, "windowWillClose:", funcptr(_chocWindowWillClose), "v@:@") == "0" { emit 0 }
    } else {
        if chocClassAddMethod(c, "application:openFile:", funcptr(_chocAppOpenFile), "B@:@@") == "0" { emit 0 }
        if chocClassAddMethod(c, "applicationShouldHandleReopen:hasVisibleWindows:", funcptr(_chocAppReopen), "B@:@B") == "0" { emit 0 }
    }
    if chocClassRegister(c) == "0" { emit 0 }
    emit c
}
// AppKit delegates are weak. The owner retains our proxy; the proxy never retains
// its owner. Retain self across dispatch so callbacks may safely detach themselves.
func _chocLifecycleSet(owner, fnPtr, key, otherKey, windowKind) {
    if owner == 0 { emit "0" }
    let proxyKey = "kr.app.lifecycle"
    if windowKind != 0 { proxyKey = "kr.window.lifecycle" }
    let owned = chocGetAssocKey(owner, proxyKey)
    let current = msg(owner, "delegate")
    if current != 0 {
        if owned == 0 || msg_1(current, "isEqual:", owned) == 0 {
            printErr("Objective-K: lifecycle owner already has another delegate\n")
            emit "0"
        }
    }
    if fnPtr == 0 {
        if owned == 0 { emit "1" }
        chocSetAssocKey(owned, key, 0)
        if chocGetAssocKey(owned, otherKey) == 0 {
            msg_1(owner, "setDelegate:", 0)
            chocSetAssocKey(owner, proxyKey, 0)
        }
        emit "1"
    }
    if owned == 0 {
        let c = _chocLifecycleClass(windowKind)
        if c == 0 { emit "0" }
        owned = msg(c, "new")
        if owned == 0 { emit "0" }
        chocSetAssocKey(owner, proxyKey, owned)
        msg(owned, "release")
    }
    chocSetAssocKey(owned, key, msg_1(cls("NSValue"), "valueWithPointer:", fnPtr))
    msg_1(owner, "setDelegate:", owned)
    emit "1"
}
func chocWindowShouldClose(win, fnPtr) {
    emit _chocLifecycleSet(win, fnPtr, "kr.window.shouldClose", "kr.window.willClose", 1)
}
func chocWindowOnClose(win, fnPtr) {
    emit _chocLifecycleSet(win, fnPtr, "kr.window.willClose", "kr.window.shouldClose", 1)
}
func chocAppOnOpenFile(app, fnPtr) {
    emit _chocLifecycleSet(app, fnPtr, "kr.app.openFile", "kr.app.reopen", 0)
}
func chocAppOnReopen(app, fnPtr) {
    emit _chocLifecycleSet(app, fnPtr, "kr.app.reopen", "kr.app.openFile", 0)
}

func chocSplit(win, x, y, w, h) {
    let sp = msg_frame(msg(cls("NSSplitView"), "alloc"), "initWithFrame:", x, y, w, h)
    msg_1(sp, "setVertical:", 1)
    _addToContentView(win, sp)
    emit sp
}
func chocSplitAdd(split, view) { msg_1(split, "addSubview:", view)  emit "1" }

func chocMenuBar(app) {
    let bar = msg(cls("NSMenu"), "new")
    msg_1(app, "setMainMenu:", bar)
    emit bar
}
// Add a top-level menu (e.g. the app menu) to the bar; returns the submenu so
// items can be added to it.
func chocMenuAdd(bar, title) {
    let item = msg_3(msg(cls("NSMenuItem"), "alloc"), "initWithTitle:action:keyEquivalent:",
        nsString(title), 0, nsString(""))
    let sub = msg_1(msg(cls("NSMenu"), "alloc"), "initWithTitle:", nsString(title))
    msg_1(item, "setSubmenu:", sub)
    msg_1(bar, "addItem:", item)
    emit sub
}
// Add a menu item bound to a built-in selector with NO target — it dispatches up
// the responder chain to the first responder (e.g. cut:/copy:/paste:/selectAll:/
// performFindPanelAction: handled by the focused NSTextView). Standard editing.
func chocMenuItemSel(menu, title, key, selName) {
    let item = msg_3(msg(cls("NSMenuItem"), "alloc"), "initWithTitle:action:keyEquivalent:",
        nsString(title), sel(selName), nsString(key))
    msg_1(menu, "addItem:", item)
    emit "1"
}
func chocMenuSeparator(menu) { msg_1(menu, "addItem:", msg(cls("NSMenuItem"), "separatorItem"))  emit "1" }
// Selector-action item carrying a tag (e.g. performTextFinderAction: reads sender.tag).
func chocMenuItemSelTag(menu, title, key, selName, tag) {
    let item = msg_3(msg(cls("NSMenuItem"), "alloc"), "initWithTitle:action:keyEquivalent:",
        nsString(title), sel(selName), nsString(key))
    msg_1(item, "setTag:", tag)
    msg_1(menu, "addItem:", item)
    emit "1"
}
// A submenu inside `menu` — returns the submenu to add items to.
func chocSubmenuIn(menu, title) {
    let item = msg_3(msg(cls("NSMenuItem"), "alloc"), "initWithTitle:action:keyEquivalent:",
        nsString(title), 0, nsString(""))
    let sub = msg_1(msg(cls("NSMenu"), "alloc"), "initWithTitle:", nsString(title))
    msg_1(item, "setSubmenu:", sub)
    msg_1(menu, "addItem:", item)
    emit sub
}
// objc-class-name-safe form of a string (alnum kept, rest -> '_').
func _classSafe(s) {
    let out = ""
    let n = len(s)
    let i = 0
    while i < n {
        let c = charCode(substring(s, i, i + 1))
        if (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) { out = out + substring(s, i, i + 1) }
        else { out = out + "_" }
        i = i + 1
    }
    emit out
}
// Add an action item to a menu, wired to a Krypton handler.
func chocMenuItem(menu, title, key, fnPtr) {
    // Key the synth class by title, NOT ("" + fnPtr): a funcptr is a raw
    // pointer whose high bytes are NUL, so "" + fnPtr truncates to the SAME
    // string for every handler -> all items collapse onto one class and fire
    // the first handler. Title-keying gives each item its own class + IMP.
    let nm = "KryptonObjkMenuCB_" + _classSafe(title) + "_" + len(title)
    let c = objc_lookUpClass(nm)
    if c == 0 {
        c = objc_allocateClassPair(cls("NSObject"), nm, 0)
        class_addMethod(c, sel("objk_dispatch:"), fnPtr, "v@:@")
        objc_registerClassPair(c)
    }
    let target = msg(msg(c, "alloc"), "init")
    let item = msg_3(msg(cls("NSMenuItem"), "alloc"), "initWithTitle:action:keyEquivalent:",
        nsString(title), sel("objk_dispatch:"), nsString(key))
    msg_1(item, "setTarget:", target)
    msg_1(menu, "addItem:", item)
    emit "1"
}


func _addToContentView(win, view) {
    let cv = msg(win, "contentView")
    msg_1(cv, "addSubview:", view)
}
