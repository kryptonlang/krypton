// stdlib/socam_linux/app.k — Linux Application lifecycle for Socam (pure Krypton).
//
// Linux counterpart to socam_app on macOS. Pure Wayland wire protocol over
// k:wayland. No toolkit dependency, no forkx — the same functions give
// you an app handle on any Wayland compositor, or 0/"connect failed" on
// a headless box.
module socam_linux_app

import "k:wayland"
import "k:smack/compositor"
import "k:socam_linux/delegate"
import "k:socam_linux/events"

// Connect and bind compositor/shm/xdg_wm_base/seat. Returns an app handle or 0.
// The app struct carries "nextId" — its Wayland object id counter. Module-
// level `let` state does not persist across imports in Krypton, so all
// allocations flow through this struct (each caller gets a fresh handle via
// the return value).
func socamLinuxAppConnect() {
    let fd = wlConnect()
    if fd < 0 { emit 0 }
    let app = structNew()
    app = setField(app, "fd", fd)
    let nextId = 2
    let REG = nextId
    nextId = nextId + 1
    app = setField(app, "reg", REG)
    let COMP = nextId
    nextId = nextId + 1
    let SHM = nextId
    nextId = nextId + 1
    let WM = nextId
    nextId = nextId + 1

    wlGetRegistry(fd, REG)
    let rb = bufNew(8192)
    let SYNCB = nextId
    nextId = nextId + 1
    let rn = wlSyncRegistry(fd, SYNCB, rb, 8192)
    if rn < 0 {
        sockClose(fd)
        emit 0
    }
    let compName = wlRegistryFind(rb, rn, "wl_compositor")
    let shmName = wlRegistryFind(rb, rn, "wl_shm")
    let xdgName = wlRegistryFind(rb, rn, "xdg_wm_base")
    let seatName = wlRegistryFind(rb, rn, "wl_seat")
    if compName < 0 || shmName < 0 || xdgName < 0 {
        sockClose(fd)
        emit 0
    }
    app = setField(app, "comp", COMP)
    app = setField(app, "shm", SHM)
    app = setField(app, "wm", WM)
    wlBind(fd, REG, compName, "wl_compositor", 4, COMP)
    wlBind(fd, REG, shmName,  "wl_shm", 1, SHM)
    wlBind(fd, REG, xdgName,  "xdg_wm_base", 1, WM)
    if seatName >= 0 {
        let SEAT = nextId
        nextId = nextId + 1
        let KB = nextId
        nextId = nextId + 1
        let PTR = nextId
        nextId = nextId + 1
        app = setField(app, "seat", SEAT)
        app = setField(app, "kb", KB)
        app = setField(app, "ptr", PTR)
        wlBind(fd, REG, seatName, "wl_seat", 5, SEAT)
        wlGetKeyboard(fd, SEAT, KB)
        wlGetPointer(fd, SEAT, PTR)
    }
    app = setField(app, "nextId", nextId)
    emit app
}

// Close the Wayland connection.
func socamLinuxAppQuit(app) {
    let fd = getField(app, "fd")
    sockClose(fd)
    app = setField(app, "closed", 1)
    emit app
}

// Pump the event queue: pong server pings, ack xdg_surface configures, and
// route every other event to the app's catch-all delegate (if set).
// Returns 1 while the connection is still alive. Call this repeatedly (once
// per frame, or in a blocking loop) — apps register their interest on the app
// struct via socamLinuxOnEvent / socamLinuxSetDelegate.
func socamLinuxAppPump(app) {
    let fd = getField(app, "fd")
    let delegate = socamLinuxDelegate(app)
    let delegateCtx = socamLinuxDelegateContext(app)

    let eb = bufNew(8192)
    let en = wlRecvInto(fd, eb, 8192)
    if en <= 0 { emit 0 }
    let off = 0
    while off + 8 <= en {
        let obj = wlObject(eb, off)
        let op = wlOpcode(eb, off)
        let s = wlSize(eb, off)
        if s < 8 { off = en }
        else {
            let wm = getField(app, "wm")
            if obj == wm && op == 0 {
                wlPong(fd, wm, wlU32(eb, off + 8))
                off = off + s
                continue
            }
            let handler = socamLinuxEventHandler(app, obj, op)
            if handler != 0 {
                let ctx = socamLinuxEventContext(app, obj, op)
                callPtr(handler, ctx, obj, op, off, s)
            } else if delegate != 0 {
                callPtr(delegate, delegateCtx, obj, op, off, s)
            }
            off = off + s
        }
        if off > en { off = en }
    }
    emit 1
}

// Thin legacy wrapper: wait for the first xdg_surface.configure and ack it.
// Now based on socamLinuxAppPump by registering a one-shot configure handler
// on the app for the correct xdg_surface object id, then running the pump.
// Use socamLinuxOnEvent + socamLinuxAppPump directly in new code.
func socamLinuxAppDrain(app, win) {
    if win == 0 {
        // no window context — drain everything and count configures acked
        let tries = 0
        let acked = 0
        while tries < 32 && acked == 0 {
            tries += 1
            acked = socamLinuxAppPump(app)
        }
        emit acked
    }
    // window case: xdg_surface.configure handler is set by the window
    let acked = 0
    let eb = bufNew(8192)
    let fd = getField(app, "fd")
    let nextId = getField(app, "nextId")
    let tries = 0
    while tries < 32 && acked == 0 {
        tries += 1
        let en = wlRecvInto(fd, eb, 8192)
        if en <= 0 { emit 0 }
        let off = 0
        while off + 8 <= en {
            let obj = wlObject(eb, off)
            let op = wlOpcode(eb, off)
            let s = wlSize(eb, off)
            if s < 8 { off = en }
            else {
                if obj == getField(app, "wm") && op == 0 {
                    wlPong(fd, getField(app, "wm"), wlU32(eb, off + 8))
                }
                else if obj == getField(win, "xdgS") && op == 0 {
                    wlAckConfigure(fd, getField(win, "xdgS"), wlU32(eb, off + 8))
                    acked = 1
                }
                off = off + s
            }
            if off > en { off = en }
        }
    }
    emit acked
}

// Derive an appid from title — lowercase alnum/hyphen only.
func appidOf(title) {
    let out = ""
    let i = 0
    let n = len(title)
    while i < n {
        let c = title[i]
        let cc = charCode(c)
        if (cc >= 97 && cc <= 122) || (cc >= 48 && cc <= 57) { out = out + c }
        else if cc == 32 || cc == 95 || cc == 45 { out = out + "-" }
        i = i + 1
    }
    if len(out) == 0 { emit "socam-linux" }
    emit out
}

// Commit a window surface by allocating a wlbuffer backed by the smack
// surface pixels. If the caller passes a nil surface this is a no-op.
// Per-frame bookkeeping (nextId / prevBuf / prevPool / prevMfd) lives in the
// WIN struct — module-level `let` state does not persist across imports.
// Emits the updated win (caller must reassign), or 0 on failure.
func socamLinuxAppRepaint(app, win, surf) {
    if win == 0 || surf == 0 { emit 0 }
    let fd = getField(app, "fd")
    let shm = getField(app, "shm")
    let wlSurf = getField(win, "surf")
    let stride = getField(win, "w") * 4
    let sz = stride * getField(win, "h")

    let nextId = getField(win, "nextId")
    if nextId == 0 { nextId = 100 }
    let poolId = nextId
    let bufId = nextId + 1
    win = setField(win, "nextId", nextId + 2)

    let prevBuf = getField(win, "prevBuf")
    if prevBuf != 0 {
        wlBufferDestroy(fd, prevBuf)
        wlPoolDestroy(fd, getField(win, "prevPool"))
        sockClose(getField(win, "prevMfd"))
    }

    let m = memfdCreate(sz)
    if m < 0 { sockClose(m); emit 0 }
    let px = mmapShared(m, sz)
    let src = smackSurfaceBuffer(surf)
    let k = 0
    while k < sz {
        bufSetByte(px, k, bufGetByte(src, k))
        k = k + 1
    }

    wlCreatePool(fd, shm, poolId, m, sz)
    wlPoolCreateBuffer(fd, poolId, bufId, 0, getField(win, "w"), getField(win, "h"), stride, 1)
    wlSurfaceAttach(fd, wlSurf, bufId, 0, 0)
    wlDamage(fd, wlSurf, 0, 0, getField(win, "w"), getField(win, "h"))
    wlCommit(fd, wlSurf)

    win = setField(win, "prevBuf", bufId)
    win = setField(win, "prevPool", poolId)
    win = setField(win, "prevMfd", m)
    emit win
}
