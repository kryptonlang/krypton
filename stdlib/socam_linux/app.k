// stdlib/socam_linux/app.k — Linux Application lifecycle for Socam (pure Krypton).
//
// Linux counterpart to socam_app on macOS. Pure Wayland wire protocol over
// k:wayland. No toolkit dependency, no forkx — the same functions give
// you an app handle on any Wayland compositor, or 0/"connect failed" on
// a headless box.
module socam_linux_app

import "k:wayland"
import "k:smack/compositor"

// Connect and bind compositor/shm/xdg_wm_base/seat. Returns an app handle or 0.
func socamLinuxAppConnect() {
    let fd = wlConnect()
    if fd < 0 { emit 0 }
    let REG = 2
    let COMP = 3
    let SHM = 4
    let WM  = 5
    let SEAT = 6
    let KB  = 7
    let PTR = 8
    let SURF = 9
    let XS  = 10
    let TOP = 11
    let app = structNew()
    setField(app, "fd", fd)
    setField(app, "reg", REG)
    setField(app, "comp", COMP)
    setField(app, "shm", SHM)
    setField(app, "wm", WM)
    setField(app, "seat", SEAT)
    setField(app, "kb", KB)
    setField(app, "ptr", PTR)
    setField(app, "surf", SURF)
    setField(app, "xs", XS)
    setField(app, "top", TOP)
    setField(app, "nextId", 12)

    wlGetRegistry(fd, REG)
    let rb = bufNew(8192)
    let rn = wlRecvInto(fd, rb, 8192)
    let compName = wlRegistryFind(rb, rn, "wl_compositor")
    let shmName = wlRegistryFind(rb, rn, "wl_shm")
    let xdgName = wlRegistryFind(rb, rn, "xdg_wm_base")
    let seatName = wlRegistryFind(rb, rn, "wl_seat")
    if compName < 0 || shmName < 0 || xdgName < 0 || seatName < 0 {
        sockClose(fd)
        emit 0
    }
    wlBind(fd, REG, compName, "wl_compositor", 4, COMP)
    wlBind(fd, REG, shmName,  "wl_shm", 1, SHM)
    wlBind(fd, REG, xdgName,  "xdg_wm_base", 1, WM)
    wlBind(fd, REG, seatName, "wl_seat", 5, SEAT)
    wlGetKeyboard(fd, SEAT, KB)
    wlGetPointer(fd, SEAT, PTR)
    emit app
}

// Close the Wayland connection.
func socamLinuxAppQuit(app) {
    let fd = getField(app, "fd")
    sockClose(fd)
    setField(app, "closed", 1)
    emit 0
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
func socamLinuxAppRepaint(app, win, surf) {
    if win == 0 || surf == 0 { emit 0 }
    let fd = getField(app, "fd")
    let shm = getField(app, "shm")
    let wlSurf = getField(win, "surf")
    let stride = getField(win, "w") * 4
    let sz = stride * getField(win, "h")
    let nextId = getField(app, "nextId")

    let poolId = nextId
    let bufId = poolId + 1
    setField(app, "nextId", nextId + 2)

    let m = memfdCreate(sz)
    let px = mmapShared(m, sz)
    let src = smackSurfaceBuffer(surf)
    if px == 0 || src == 0 { sockClose(m); emit 0 }
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

    sockClose(m)
    emit 1
}
