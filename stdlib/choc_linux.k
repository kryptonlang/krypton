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

// Mutable state lives in the win struct (krypton module-level `let` does NOT
// persist across an import boundary — see k:server_native's header note;
// verified 2026-11-17). Every function that changes state takes the win
// handle and emits it back; callers MUST keep the latest handle.
// Field map: nextId (dense object id counter), prevBuf/prevPool/prevMfd
// (last frame's wl_buffer, pool, memfd), dirty, quit, onKey, onPointer.

// ── colors it needs ──────────────────────────────────────────────────
func chocColor(r, g, b) { emit r * 65536 + g * 256 + b }

// ── lifecycle ─────────────────────────────────────────────────────────
func chocInit() { emit 1 }
func chocSharedApp() { emit 1 }
func chocQuit(win) {
    if win == "" { emit 1 }
    win = setField(win, "quit", 1)
    emit win
}
func chocRun(win) {
    // The quit flag lives in the win struct; the app that calls chocQuit
    // must thread the same win the loop polls.
    win = setField(win, "quit", 0)
    while getField(win, "quit") != 1 {
        let eb = bufNew(8192)
        let en = wlRecvInto(getField(win, "fd"), eb, 8192)
        if en <= 0 { win = setField(win, "quit", 1) }
        if en > 0 {
            let off = 0
            while off + 8 <= en {
                let obj = wlObject(eb, off)
                let op = wlOpcode(eb, off)
                let s = wlSize(eb, off)
                if s < 8 { off = en }
                else {
                    win = _chocDispatchEvent(win, eb, off, obj, op, s)
                    off = off + s
                }
            }
        }
        // If the WM configured us (configure event marks dirty), re-present.
        if getField(win, "dirty") == 1 { win = setField(win, "dirty", 0); win = _chocPresentFrame(win) }
    }
    sockClose(getField(win, "fd"))
    emit win
}

// ── window ───────────────────────────────────────────────────────────
func chocWindow(app, title, w, h) {
    let fd = wlConnect()
    if fd < 0 { print("connect failed"); exit(1) }
    let nextId = 2
    let REG = nextId
    nextId = nextId + 1
    wlGetRegistry(fd, REG)
    let rb = bufNew(8192)
    let SYNCB = nextId
    nextId = nextId + 1
    let rn = wlSyncRegistry(fd, SYNCB, rb, 8192)
    if rn < 0 {
        print("refused: registry handshake failed"); exit("1")
    }
    let compName = wlRegistryFind(rb, rn, "wl_compositor")
    let shmName = wlRegistryFind(rb, rn, "wl_shm")
    let xdgName = wlRegistryFind(rb, rn, "xdg_wm_base")
    let seatName = wlRegistryFind(rb, rn, "wl_seat")
    if compName < 0 || shmName < 0 || xdgName < 0 {
        print("refused: missing required globals"); exit("1")
    }
    let COMP = nextId
    nextId = nextId + 1
    let SHM = nextId
    nextId = nextId + 1
    let WM = nextId
    nextId = nextId + 1
    let SEAT = 0
    let KB  = 0
    let PTR = 0
    let TI = 0
    wlBind(fd, REG, compName, "wl_compositor", 4, COMP)
    wlBind(fd, REG, shmName, "wl_shm", 1, SHM)
    wlBind(fd, REG, xdgName, "xdg_wm_base", 1, WM)
    if seatName >= 0 {
        SEAT = nextId
        nextId = nextId + 1
        KB = nextId
        nextId = nextId + 1
        PTR = nextId
        nextId = nextId + 1
        wlBind(fd, REG, seatName, "wl_seat", 5, SEAT)
        wlGetKeyboard(fd, SEAT, KB)
        wlGetPointer(fd, SEAT, PTR)
        // Bind the unstable text-input manager when the compositor exposes it
        // (Hyprland does). Fall back to plain wl_keyboard ASCII typing.
        let tiName = wlRegistryFind(rb, rn, "zwp_text_input_manager_v3")
        if tiName >= 0 {
            TI = nextId
            nextId = nextId + 1
            wlGetTextInput(fd, tiName, TI, SEAT)
        }
    }
    let SURF = nextId
    nextId = nextId + 1
    let XS = nextId
    nextId = nextId + 1
    let TOP = nextId
    nextId = nextId + 1
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
    state = setField(state, "ti", TI)
    state = setField(state, "closed", 0)
    state = setField(state, "lastText", "")
    state = setField(state, "onText", 0)
    state = setField(state, "pointerX", 0)
    state = setField(state, "pointerY", 0)
    state = setField(state, "scale", 1)
    state = setField(state, "smack", smack)
    state = setField(state, "font", font)
    state = setField(state, "nextId", nextId)
    state = setField(state, "prevBuf", 0)
    state = setField(state, "prevPool", 0)
    state = setField(state, "prevMfd", 0)
    state = setField(state, "dirty", 1)
    state = setField(state, "quit", 0)
    state = setField(state, "onKey", 0)
    state = setField(state, "onPointer", 0)
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
    let prevBuf = getField(win, "prevBuf")
    if prevBuf != 0 {
        wlBufferDestroy(fd, prevBuf)
        wlPoolDestroy(fd, getField(win, "prevPool"))
        sockClose(getField(win, "prevMfd"))
    }
    let nextId = getField(win, "nextId")
    if nextId == 0 { nextId = 1000 }
    let pool = nextId
    let buf = nextId + 1
    win = setField(win, "nextId", nextId + 2)

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

    win = setField(win, "prevBuf", buf)
    win = setField(win, "prevPool", pool)
    win = setField(win, "prevMfd", m)
    emit win
}

func _chocPresentFrame(win) { win = chocPresent(win)  emit win }

// Key events (kb op==3): args at off+16 = keycode, +20 = key state,
// +24 = modifiers (1=shift, 2=ctrl, 4=alt, 8=super).
func _chocDispatchEvent(win, eb, off, obj, op, sizeB) {
    let fd = getField(win, "fd")
    let wm = getField(win, "wm")
    if obj == wm && op == 0 { wlPong(fd, wm, wlU32(eb, off + 8)) }
    else if obj == getField(win, "xdg") && op == 0 { wlAckConfigure(fd, getField(win, "xdg"), wlU32(eb, off + 8)); win = setField(win, "dirty", 1) }
    else if obj == getField(win, "top") && op == 0 {
        let cw = wlU32(eb, off + 8)
        let chh = wlU32(eb, off + 12)
        if cw > 0 && chh > 0 {
            win = setField(win, "w", cw)
            win = setField(win, "h", chh)
        }
        win = setField(win, "dirty", 1)
    }
    else if obj == getField(win, "top") && op == 1 {
        // xdg_toplevel.close — the user closed the window.
        win = setField(win, "closed", 1)
    }
    else if obj == getField(win, "ti") && op == 3 {
        // zwp_text_input_v3.commit_string — deliver committed text.
        let cb = getField(win, "onText")
        let txt = wlTextInputEventText(eb, off)
        win = setField(win, "lastText", txt)
        if cb != 0 { callPtr(cb, txt) }
    }
    else if obj == getField(win, "kb") && op == 3 {
        let st = wlU32(eb, off + 20)
        let cb = getField(win, "onKey")
        if st == 1 && cb != 0 {
            callPtr(cb, wlU32(eb, off + 16), wlU32(eb, off + 24))
        }
    }
    else if obj == getField(win, "ptr") && op == 1 {
        let fx = wlU32(eb, off + 16)
        let fy = wlU32(eb, off + 24)
        win = setField(win, "pointerX", fx / 256)
        win = setField(win, "pointerY", fy / 256)
        let cb = getField(win, "onPointer")
        if cb != 0 { callPtr(cb, fx / 256, fy / 256) }
    }
    else if obj == 1 && op == 0 { print("wl error code=" + wlU32(eb, off + 12)) }
    emit win
}

func chocOnKey(win, fnPtr) {
    if win == "" { emit 0 }
    win = setField(win, "onKey", toInt(fnPtr))
    emit win
}
func chocOnPointer(win, fnPtr) {
    if win == "" { emit 0 }
    win = setField(win, "onPointer", toInt(fnPtr))
    emit win
}
func chocOnText(win, fnPtr) {
    if win == "" { emit 0 }
    win = setField(win, "onText", toInt(fnPtr))
    emit 1
}
func chocTextInputEnable(win) {
    let ti = getField(win, "ti")
    if ti != 0 {
        wlTextInputEnable(getField(win, "fd"), ti)
        emit 1
    }
    emit 0
}
func chocTextInputDisable(win) {
    let ti = getField(win, "ti")
    if ti != 0 {
        wlTextInputDisable(getField(win, "fd"), ti)
    }
    emit 0
}
func chocSetScale(win, scale) {
    if win == "" { emit win }
    win = setField(win, "scale", toInt(scale))
    emit win
}

// Partial present: damage_buffer per rect in damageText ("x,y,w,h,..."),
// then attach+commit. damageText == "" → full damage (adapter fallback).
// (AppKit parity shape: same attach/damage/commit contract, minus the
// separate frame callback — v0 commits synchronously.)
func chocPresentDamage(win, damageText) {
    if win == "" { emit win }
    let fd = getField(win, "fd")
    let surf = getField(win, "surf")
    if damageText == "" {
        wlDamageBuffer(fd, surf, 0, 0, getField(win, "w"), getField(win, "h"))
    } else {
        let parts = count(damageText)
        let i = 0
        while i + 3 < parts {
            let x = toInt(split(damageText, i))
            let y = toInt(split(damageText, i + 1))
            let w = toInt(split(damageText, i + 2))
            let h = toInt(split(damageText, i + 3))
            wlDamageBuffer(fd, surf, x, y, w, h)
            i += 4
        }
    }
    wlCommit(fd, surf)
    emit win
}

// Single command: pump one event batch; present the frame if dirty.
// Emits the (possibly updated) win handle — reassign it.
func chocPumpEvents(win) {
    if win == "" { emit 0 }
    let fd = getField(win, "fd")
    let eb = bufNew(8192)
    let en = wlRecvInto(fd, eb, 8192)
    if en > 0 {
        let off = 0
        while off + 8 <= en {
            let obj = wlObject(eb, off)
            let op = wlOpcode(eb, off)
            let s = wlSize(eb, off)
            if s < 8 { off = en }
            else {
                win = _chocDispatchEvent(win, eb, off, obj, op, s)
                off = off + s
            }
        }
    }
    if getField(win, "dirty") == 1 { win = setField(win, "dirty", 0); win = _chocPresentFrame(win) }
    emit win
}

// Minimal convenience query used by apps: is the window ready?
func chocWindowReady(win) {
    if win == "" { emit 0 }
    emit 1
}
