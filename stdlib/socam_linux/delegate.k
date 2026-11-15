// stdlib/socam_linux/delegate.k — catch-all responder for Socam/Linux.
//
// On macOS, delegates are Objective-C classes registered against NSWindow
// events. On Linux there is no Objective-C runtime in the ELF backend; an
// "event delegate" is a single Krypton function pointer attached to the
// app struct — the event pump routes every unhandled event to it.
module socam_linux_delegate

import "k:socam_linux/events"

// Attach a catch-all delegate to the app. Every event not claimed by a
// registered handler ((objectId, opcode) pair) is delivered here.
// handlerFn: funcptr() to   func(ctx, obj, op, off, sizeB) -> void
// ctx: whatever ctx the app wants carried through to the callback
// (typically the app struct itself).
func socamLinuxSetDelegate(app, ctx, handlerFn) {
    app = setField(app, "delegate", handlerFn)
    app = setField(app, "delegateCtx", ctx)
    emit app
}

// Return the current delegate or 0 if unset.
func socamLinuxDelegate(app) {
    emit getField(app, "delegate")
}

// Return the current delegate context or 0 if unset.
func socamLinuxDelegateContext(app) {
    emit getField(app, "delegateCtx")
}
