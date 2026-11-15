// stdlib/socam_linux/window.k — Linux Window management for Socam (pure Krypton).
module socam_linux_window

import "k:wayland"
import "k:smack/compositor"
import "k:socam_linux/app"

// Create a top-level Wayland surface + xdg toplevel, commit it.
// Returns a window struct or 0 on failure.
func socamLinuxWindowCreate(app, w, h, title) {
    if app == 0 { emit 0 }
    let fd = getField(app, "fd")
    let nextId = getField(app, "nextId")
    let surf = nextId
    let xdgSurf = nextId + 1
    let topId = nextId + 2
    setField(app, "nextId", nextId + 3)

    wlCreateSurface(fd, getField(app, "comp"), surf)
    wlGetXdgSurface(fd, getField(app, "wm"), xdgSurf, surf)
    wlGetToplevel(fd, xdgSurf, topId)

    let win = structNew()
    setField(win, "fd", fd)
    setField(win, "surf", surf)
    setField(win, "xdgS", xdgSurf)
    setField(win, "top", topId)
    setField(win, "w", toInt(w))
    setField(win, "h", toInt(h))
    setField(win, "app", app)
    setField(win, "title", title)
    setField(win, "appid", appidOf(title))
    setField(win, "closed", 0)

    wlSetTitle(fd, topId, title)
    wlSetAppId(fd, topId, appidOf(title))

    wlCommit(fd, surf)
    emit win
}

// Set the window title at runtime.
func socamLinuxWindowSetTitle(win, title) {
    if win == 0 { emit 0 }
    let fd = getField(win, "fd")
    let top = getField(win, "top")
    wlSetTitle(fd, top, title)
    setField(win, "title", title)
    emit 1
}

// Mark the window as closed.
func socamLinuxWindowClose(win) {
    if win == 0 { emit 0 }
    setField(win, "closed", 1)
    emit 1
}
