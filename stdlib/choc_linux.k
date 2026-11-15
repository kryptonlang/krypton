// stdlib/choc_linux.k — Linux slice of the choc UI kit (pure Krypton).
//
// Copyright 2026 The Krypton Authors. Licensed under the Apache License, Version 2.0.
//
// choc_macos.k binds AppKit through the Objective-C FFI; Linux has neither
// AppKit nor a usable foreign-call path in the ELF backend (no libc linking,
// raw syscalls only). This slice therefore talks the Wayland wire protocol
// directly (k:wayland) and renders into an in-arena SmackSurface, blitting
// pixels via wl_shm. No libwayland, no GTK, no FFI — works on the same
// static-syscall ELF pipeline as cortex_wl.k.
//
// API mirrors choc_macos where the semantics carry over. Deliberate
// single-window MVP deviations (documented, not hidden):
//   - chocSharedApp() returns a constant the caller threads back in; there is
//     one window at a time.
//   - chocRun(win) pumps the Wayland loop until chocQuit(win) is called on it.
//     The parameter is the window (not an NSApplication) for the same reason.
//   - Controls (button/checkbox/...) do not exist yet. chocFillRect /
//     chocDrawText + hit-testing via chocOnKey/chocOnPointer are the
//     primitives an application is expected to build from.
//
// Drawing colors are 24-bit RGB ints (0xRRGGBB), matching k:x11/wayland.k.

module choc_linux

import "k:wayland"
import "k:smack/compositor"

// Single-window MVP state that must escape a single call frame: the Wayland
// event loop polls these module-globals every iteration, because struct
// handles passed by value cannot push an update back to the caller.
let chocQuitFlag = 0
let chocDirtyFlag = 1
let chocOnKeyCb = 0
let chocOnPointerCb = 0
let chocPrevBuf = 0
let chocPrevPool = 0
let chocPrevMfd = 0

// ── colors it needs ──────────────────────────────────────────────────
func chocColor(r, g, b) { emit r * 65536 + g * 256 + b }

// ── lifecycle ─────────────────────────────────────────────────────────
func chocInit() { emit 1 }
func chocSharedApp() { emit 1 }
func chocQuit(win) {
    if win == "" { emit 1 }
    else {
        chocQuitFlag = 1
        emit 1
    }
}
func chocRun(win) {
    // Pump the Wayland loop until chocQuit(win) is set (or the server closes us).
    chocQuitFlag = 0
    while chocQuitFlag != 1 {
        let eb = bufNew(8192)
        let en = wlRecvInto(getField(win, "fd"), eb, 8192)
        if en <= 0 { chocQuitFlag = 1 }
        if en > 0 {
            let off = 0
            while off + 8 <= en {
                let obj = wlObject(eb, off)
                let op = wlOpcode(eb, off)
                let s = wlSize(eb, off)
                if s < 8 { off = en }
                else {
                    _chocDispatchEvent(win, eb, off, obj, op, s)
                    off = off + s
                }
            }
        }
        // If the WM configured us (configure event marks dirty), re-present.
        if chocDirtyFlag == 1 { chocDirtyFlag = 0; _chocPresentFrame(win) }
    }
    sockClose(getField(win, "fd"))
    emit 0
}

// ── window ───────────────────────────────────────────────────────────
func chocWindow(app, title, w, h) {
    let fd = wlConnect()
    if fd < 0 { print("connect failed"); exit(1) }
    let REG = wlNewId()
    wlGetRegistry(fd, REG)
    let rb = bufNew(8192)
    let rn = wlRecvInto(fd, rb, 8192)
    let compName = wlRegistryFind(rb, rn, "wl_compositor")
    let shmName = wlRegistryFind(rb, rn, "wl_shm")
    let xdgName = wlRegistryFind(rb, rn, "xdg_wm_base")
    let seatName = wlRegistryFind(rb, rn, "wl_seat")
    if compName < 0 || shmName < 0 || xdgName < 0 {
        print("refused: missing required globals"); exit("1")
    }
    let COMP = wlNewId()
    let SHM = wlNewId()
    let WM = wlNewId()
    let SEAT = 0
    let KB  = 0
    let PTR = 0
    wlBind(fd, REG, compName, "wl_compositor", 4, COMP)
    wlBind(fd, REG, shmName, "wl_shm", 1, SHM)
    wlBind(fd, REG, xdgName, "xdg_wm_base", 1, WM)
    if seatName >= 0 {
        SEAT = wlNewId()
        KB = wlNewId()
        PTR = wlNewId()
        wlBind(fd, REG, seatName, "wl_seat", 5, SEAT)
        wlGetKeyboard(fd, SEAT, KB)
        wlGetPointer(fd, SEAT, PTR)
    }
    let SURF = wlNewId()
    let XS = wlNewId()
    let TOP = wlNewId()
    wlCreateSurface(fd, COMP, SURF)
    wlGetXdgSurface(fd, WM, XS, SURF)
    wlGetToplevel(fd, XS, TOP)
    wlSetTitle(fd, TOP, title)
    wlSetAppId(fd, TOP, appidOf(title))
    wlCommit(fd, SURF)

    let font = wlFontLoad()
    let smack = smackSurface(w, h)
    let state = structNew()
    state = setField(state, "fd", fd)
    state = setField(state, "w", toInt(w))
    state = setField(state, "h", toInt(h))
    state = setField(state, "surf", SURF)
    state = setField(state, "xdg", XS)
    state = setField(state, "top", TOP)
    state = setField(state, "shm", SHM)
    state = setField(state, "wm", WM)
    state = setField(state, "kb", KB)
    state = setField(state, "ptr", PTR)
    state = setField(state, "smack", smack)
    state = setField(state, "font", font)
    chocDirtyFlag = 1
    emit state
}

func chocShow(win, app) { emit 1 }   // mapped on create; no-op for API parity
func chocTransparentTitlebar(win) { emit 1 }  // Wayland has no such thing
func chocSetWindowMinSize(win, w, h) { emit 1 }

func chocSetTitle(win, title) {
    if win == "" { emit 0 }
    else {
        wlSetTitle(getField(win, "fd"), getField(win, "top"), title)
        emit 1
    }
}

// appid from the title: lowercase, strip to [a-z0-9-]
func appidOf(title) {
    let out = ""
    let i = 0
    let n = len(title)
    while i < n {
        let c = title[i]
        let cc = charCode(c)
        if (cc >= 97 && cc <= 122) || (cc >= 48 && cc <= 57) { out = out + c }
        else if cc == 32 || cc == 95 || cc == 45 { out = out + "-" }
        i += 1
    }
    if len(out) == 0 { emit "choc-linux" }
    emit out
}

// ── drawing ─────────────────────────────────────────────────────────
func chocClear(win, color) {
    if win == "" { emit 0 }
    smackSurfaceClear(getField(win, "smack"), color)
    emit 1
}
func chocFillRect(win, x, y, w, h, color) {
    if win == "" { emit 0 }
    smackSurfaceFillRect(getField(win, "smack"), toInt(x), toInt(y), toInt(w), toInt(h), color)
    emit 1
}
func chocStrokeRect(win, x, y, w, h, color, borderWidth) {
    if win == "" { emit 0 }
    smackSurfaceStrokeRect(getField(win, "smack"), toInt(x), toInt(y), toInt(w), toInt(h), color, toInt(borderWidth))
    emit 1
}
func chocDrawText(win, x, y, text, color) {
    if win == "" { emit 0 }
    let font = getField(win, "font")
    let smack = getField(win, "smack")
    let px = smackSurfaceBuffer(smack)
    let w = smackSurfaceWidth(smack)
    let h = smackSurfaceHeight(smack)
    if px == "" { emit 0 }
    fbDrawText(px, w, h, font, toInt(x), toInt(y), text, color)
    emit 1
}

// ── present + event dispatch ─────────────────────────────────────────
// Blit the SmackSurface into a fresh wl_buffer (memfd + pool) and attach it.
// Fresh ids per frame; previous frame is destroyed (ids never reused).
func chocPresent(win) {
    if win == "" { emit 0 }
    let fd = getField(win, "fd")
    let W = getField(win, "w")
    let H = getField(win, "h")
    let smack = getField(win, "smack")
    let stride = W * 4
    let sz = stride * H

    // free the previous frame
    if chocPrevBuf != 0 {
        wlBufferDestroy(fd, chocPrevBuf)
        wlPoolDestroy(fd, chocPrevPool)
        sockClose(chocPrevMfd)
    }
    let pool = wlNewId()
    let buf = wlNewId()

    let m = memfdCreate(sz)
    if m < 0 { print("choc_linux: memfdCreate failed"); exit("1") }
    let px = mmapShared(m, sz)
    let sb = smackSurfaceBuffer(smack)
    let i = 0
    while i < sz {
        bufSetByte(px, i, bufGetByte(sb, i))
        i = i + 1
    }

    wlCreatePool(fd, getField(win, "shm"), pool, m, sz)
    wlPoolCreateBuffer(fd, pool, buf, 0, W, H, stride, 1)
    wlSurfaceAttach(fd, getField(win, "surf"), buf, 0, 0)
    wlDamage(fd, getField(win, "surf"), 0, 0, W, H)
    wlCommit(fd, getField(win, "surf"))

    chocPrevBuf = buf
    chocPrevPool = pool
    chocPrevMfd = m
    emit 1
}

func _chocPresentFrame(win) { chocPresent(win) }

// Key events (kb op==3): args at off+16 = keycode, +20 = key state,
// +24 = modifiers (1=shift, 2=ctrl, 4=alt, 8=super).
func _chocDispatchEvent(win, eb, off, obj, op, sizeB) {
    let fd = getField(win, "fd")
    let wm = getField(win, "wm")
    if obj == wm && op == 0 { wlPong(fd, wm, wlU32(eb, off + 8)) }
    else if obj == getField(win, "xdg") && op == 0 { wlAckConfigure(fd, getField(win, "xdg"), wlU32(eb, off + 8)); chocDirtyFlag = 1 }
    else if obj == getField(win, "top") && op == 0 {
        let cw = wlU32(eb, off + 8)
        let chh = wlU32(eb, off + 12)
        if cw > 0 && chh > 0 {
            win = setField(win, "w", cw)
            win = setField(win, "h", chh)
        }
        chocDirtyFlag = 1
    }
    else if obj == getField(win, "kb") && op == 3 {
        let st = wlU32(eb, off + 20)
        if st == 1 {
            if chocOnKeyCb != 0 {
                callPtr(chocOnKeyCb, wlU32(eb, off + 16), wlU32(eb, off + 24))
            }
        }
    }
    else if obj == getField(win, "ptr") && op == 1 {
        let fx = wlU32(eb, off + 16)
        let fy = wlU32(eb, off + 24)
        if chocOnPointerCb != 0 { callPtr(chocOnPointerCb, fx / 256, fy / 256) }
    }
    else if obj == 1 && op == 0 { print("wl error code=" + wlU32(eb, off + 12)) }
}

func chocOnKey(win, fnPtr) { chocOnKeyCb = toInt(fnPtr); emit 1 }
func chocOnPointer(win, fnPtr) { chocOnPointerCb = toInt(fnPtr); emit 1 }

// Single command: pump one event batch; returns 1 if a frame was presented.
func chocPumpEvents(win) {
    if win == "" { emit 0 }
    let fd = getField(win, "fd")
    let eb = bufNew(8192)
    let en = wlRecvInto(fd, eb, 8192)
    let any = 0
    if en > 0 {
        any = 1
        let off = 0
        while off + 8 <= en {
            let obj = wlObject(eb, off)
            let op = wlOpcode(eb, off)
            let s = wlSize(eb, off)
            if s < 8 { off = en }
            else {
                _chocDispatchEvent(win, eb, off, obj, op, s)
                off = off + s
            }
        }
    }
    if chocDirtyFlag == 1 { chocDirtyFlag = 0; _chocPresentFrame(win) }
    emit any
}

// Minimal convenience query used by apps: is the window ready?
func chocWindowReady(win) {
    if win == "" { emit 0 }
    emit 1
}
