// stdlib/socam/window.k — Window management for Socam (macOS, pure Krypton).
//
// Provides an idiomatic SwiftUI-style Window struct over NSWindow via the
// same struct/handler pattern as choc_linux's window API. No FFI beyond
// the existing choc_macos primitives.
module socam_window

import "k:objc"
import "k:objk"
import "k:choc_macos"

// Create an NSWindow with the given content rect and default style.
// x,y,w,h are integers (CGFloat on arm64 — both are 64-bit).
// styleMask defaults to titled|closable|miniaturizable|resizable = 15.
func socamWindowCreate(x, y, w, h, title) {
    let mask = 15
    let raw = msg(cls("NSWindow"), "alloc")
    let win = msg_rect(raw, "initWithContentRect:styleMask:backing:defer:",
        toInt(x), toInt(y), toInt(w), toInt(h), mask, 2, 0)
    if title != "" { msg_1(win, "setTitle:", nsString(title)) }
    emit win
}
// Show the window and bring it to the front with the given application.
func socamWindowShow(win, app) { chocShow(win, app) }
// Attach a Metal layer to the window's content view at the given size.
func socamWindowAttachMetalLayer(win, w, h) {
    let cv = msg(win, "contentView")
    if cv == 0 { emit 0 }
    let layer = msg(msg(cls("CAMetalLayer"), "alloc"), "init")
    msg_d2(layer, "setDrawableSize:", toInt(w), toInt(h))
    msg_1(cv, "setWantsLayer:", 1)
    msg_1(cv, "setLayer:", layer)
    emit layer
}
// Get the content view for further layout work.
func socamWindowContentView(win) { emit msg(win, "contentView") }

// Set the title bar to transparent (modern macOS look).
func socamWindowTransparentTitlebar(win) { emit chocTransparentTitlebar(win) }
