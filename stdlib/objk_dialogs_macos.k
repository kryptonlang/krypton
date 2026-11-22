// Scrollable native modal text dialogs, implemented entirely in Krypton.
// Call only on the main AppKit thread. Native runModal result is 1000 for OK
// and 1001 for Cancel. This is not a nonblocking sheet API.
module objk_dialogs_macos
import "k:objc"
func okScrollableDialog(title, text, canCancel) {
    let alert = allocInit("NSAlert")
    msg_1(alert, "setMessageText:", nsString(title))
    msg_1(alert, "addButtonWithTitle:", nsString("OK"))
    if canCancel != 0 { msg_1(alert, "addButtonWithTitle:", nsString("Cancel")) }
    let scroll = msg_frame(msg(cls("NSScrollView"), "alloc"), "initWithFrame:", 0, 0, 560, 300)
    let view = msg_frame(msg(cls("NSTextView"), "alloc"), "initWithFrame:", 0, 0, 540, 300)
    msg_1(scroll, "setHasVerticalScroller:", 1)
    msg_1(view, "setEditable:", 0)
    msg_1(view, "setSelectable:", 1)
    msg_1(view, "setVerticallyResizable:", 1)
    msg_1(view, "setHorizontallyResizable:", 0)
    msg_1(view, "setAutoresizingMask:", 2)
    msg_1(msg(view, "textContainer"), "setWidthTracksTextView:", 1)
    msg_1(view, "setString:", nsString(text))
    msg_1(scroll, "setDocumentView:", view)
    msg_1(alert, "setAccessoryView:", scroll)
    let result = msg(alert, "runModal")
    msg(view, "release")
    msg(scroll, "release")
    msg(alert, "release")
    emit result
}
