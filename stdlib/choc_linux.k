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

// ── colors it needs ──────────────────────────────────────────────────
func chocColor(r, g, b) { emit r * 65536 + g * 256 + b }

// ── lifecycle ─────────────────────────────────────────────────────────
func chocInit() { emit 1 }
func chocSharedApp() { emit 1 }
func chocQuit(win) {
    if win == "" { emit 1 }
    else {
        setField(win, "quit", 1)
        emit 1
    }
}
func chocRun(win) {
    // Pump the Wayland loop until chocQuit(win) is set (or the server closes us).
    while getField(win, "quit") != 1 {
        let eb = bufNew(8192)
        let en = wlRecvInto(getField(win, "fd"), eb, 8192)
        if en <= 0 { setField(win, "quit", 1) }
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
        if getField(win, "dirty") == 1 { _chocPresentFrame(win) }
    }
    sockClose(getField(win, "fd"))
    emit 0
}

// ── window ───────────────────────────────────────────────────────────
func chocWindow(app, title, w, h) {
    let fd = wlConnect()
    if fd < 0 { print("connect failed"); exit(1) }
    let REG = 2  let COMP = 3  let SHM = 4  let WM = 5  let SEAT = 6
    let KB = 7   let PTR = 8   let SURF = 9 let XS = 10 let TOP = 11
    let POOL = 12 let BUF = 13

    wlGetRegistry(fd, REG)
    let rb = bufNew(8192)
    let rn = wlRecvInto(fd, rb, 8192)
    wlBind(fd, REG, _wlFind(rb, rn, "wl_compositor"), "wl_compositor", 4, COMP)
    wlBind(fd, REG, _wlFind(rb, rn, "wl_shm"), "wl_shm", 1, SHM)
    wlBind(fd, REG, _wlFind(rb, rn, "xdg_wm_base"), "xdg_wm_base", 1, WM)
    wlBind(fd, REG, _wlFind(rb, rn, "wl_seat"), "wl_seat", 5, SEAT)
    wlGetKeyboard(fd, SEAT, KB)
    wlGetPointer(fd, SEAT, PTR)
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
    state = setField(state, "pool", POOL)
    state = setField(state, "buf", BUF)
    state = setField(state, "nextId", 14)
    state = setField(state, "smack", smack)
    state = setField(state, "font", font)
    state = setField(state, "quit", 0)
    state = setField(state, "dirty", 1)
    state = setField(state, "onKey", 0)
    state = setField(state, "onPointer", 0)
    state = setField(state, "prevBuf", 0)
    state = setField(state, "prevPool", 0)
    state = setField(state, "prevMfd", 0)
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
    if getField(win, "prevBuf") != 0 {
        wlBufferDestroy(fd, getField(win, "prevBuf"))
        wlPoolDestroy(fd, getField(win, "prevPool"))
        sockClose(getField(win, "prevMfd"))
    }
    let pool = getField(win, "nextId")
    let buf = pool + 1
    setField(win, "nextId", pool + 2)

    let m = memfdCreate(sz)
    let px = mmapShared(m, sz)
    if px == "" { print("choc_linux: mmapShared failed"); exit("1") }
    // copy SmackSurface pixels (RGBA byte order) into the shared pool
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

    setField(win, "prevBuf", buf)
    setField(win, "prevPool", pool)
    setField(win, "prevMfd", m)
    setField(win, "dirty", 0)
    emit 1
}

func _chocPresentFrame(win) { chocPresent(win) }

// Key events (kb op==3): args at off+16 = keycode, +20 = key state,
// +24 = modifiers (1=shift, 2=ctrl, 4=alt, 8=super).
func _chocDispatchEvent(win, eb, off, obj, op, sizeB) {
    let fd = getField(win, "fd")
    let wm = getField(win, "wm")
    if obj == wm && op == 0 { wlPong(fd, wm, wlU32(eb, off + 8)) }
    else if obj == getField(win, "xdg") && op == 0 { wlAckConfigure(fd, getField(win, "xdg"), wlU32(eb, off + 8)); setField(win, "dirty", 1) }
    else if obj == getField(win, "top") && op == 0 {
        let cw = wlU32(eb, off + 8)
        let chh = wlU32(eb, off + 12)
        if cw > 0 && chh > 0 {
            setField(win, "w", cw)
            setField(win, "h", chh)
        }
        setField(win, "dirty", 1)
    }
    else if obj == getField(win, "kb") && op == 3 {
        let st = wlU32(eb, off + 20)
        if st == 1 {
            let cb = getField(win, "onKey")
            if cb != 0 {
                callPtr(cb, wlU32(eb, off + 16), wlU32(eb, off + 24))
            }
        }
    }
    else if obj == getField(win, "ptr") && op == 1 {
        let fx = wlU32(eb, off + 16)
        let fy = wlU32(eb, off + 24)
        let cb = getField(win, "onPointer")
        if cb != 0 { callPtr(cb, fx / 256, fy / 256) }
    }
    else if obj == 1 && op == 0 { print("wl error code=" + wlU32(eb, off + 12)) }
}

func chocOnKey(win, fnPtr) { setField(win, "onKey", toInt(fnPtr)); emit 1 }
func chocOnPointer(win, fnPtr) { setField(win, "onPointer", toInt(fnPtr)); emit 1 }

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
    if getField(win, "dirty") == 1 { _chocPresentFrame(win) }
    emit any
}

// Minimal convenience query used by apps: is the window ready?
func chocWindowReady(win) {
    if win == "" { emit 0 }
    emit 1
}
