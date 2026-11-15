// stdlib/socam/delegate.k — Automated delegate subclassing for Socam.
//
// Wraps the objk dynamic-class infrastructure (okNewCls / okAddFn / okRegCls)
// so creating window-delegate classes and binding closures is a single call.
// Callback closure signature:  fn handleFn(self, sel, win) { ... }
// where the callback pointer is resolved via funcptr().
module socam_delegate

import "k:objc"
import "k:objk"
import "k:choc_macos"

// Create a new Objective-C subclass of NSObject named className and register
// it as the receiver for the window's close action.
//
// onCloseFn: funcptr() to a Krypton function with signature
//   func myCloseHandler(self, cmd, win) { emit 1 }
// Returns the registered class pointer, or 0 on failure.
func socamWindowDelegateClass(className, onCloseFn) {
    let c = chocClassNew(className)
    if c == 0 {
        // class already exists — look it up instead
        emit objc_lookUpClass(className)
    } else {
        if chocClassAddMethod(c, "windowShouldClose:", funcptr(onCloseFn), "B@:@") == "0" { emit 0 }
        if objc_registerClassPair(c) == 0 { emit 0 }
        emit c
    }
}
// Assign an existing Krypton callback function pointer as the handler for the
// window's close button. Creates the delegate subclass and attaches it.
func socamWindowOnClose(win, onCloseFn) {
    let c = socamWindowDelegateClass("SocamWindowDelegate", onCloseFn)
    let delegate = msg(c, "new")
    msg_1(win, "setDelegate:", delegate)
    emit delegate
}
