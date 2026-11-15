// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// termios.k — Linux termios over raw syscalls (no libc). Requires the
// BUILTIN_IOCTL Linux backend builtin to execute ioctl(2) directly.
//
// Linux x86-64 termios struct layout (kernel ABI):
//   offset  0  c_iflag (u32)      offset 16  c_line (u8)
//   offset  4  c_oflag (u32)
//   offset  8  c_cflag (u32)      offset 17.. c_cc[32] (VMIN=6, VTIME=5 -> 23/22)
//   offset 12  c_lflag (u32)      total size 60

module termios

// ioctl(2) request codes (x86-64)
let TCGETS       = 21505    // 0x5401 — get termios
let TCSETS       = 21506    // 0x5402 — set termios
let TIOCGWINSZ   = 21523    // 0x5413 — get window size
let TIOCSWINSZ   = 21524    // 0x5414 — set window size

// c_lflag bits
let ISIG    = 1
let ICANON  = 2
let ECHO    = 8
let ECHOE   = 16
let ECHOK   = 32
let ECHONL  = 64
let IEXTEN  = 32768

// c_iflag bits we clear in raw mode
let BRKINT  = 1
let INLCR   = 64
let IGNCR   = 128
let ICRNL   = 256
let IXON    = 1024

let LFLAG_OFF = 12
let CFLAG_OFF = 8
let VMIN_OFF  = 23
let VTIME_OFF = 22

// Current termios in a 60-byte buf; NULL sentinel (0) on error — never
// compare a zeroed buffer to "" (strcmp would say "equal").
func termGet(fd) {
    let b = bufNew(60)
    let rc = ioctl(toInt(fd), TCGETS, b)
    if rc != 0 { emit 0 }
    emit b
}

// Write a 60-byte buf back; 1 on success, 0 on error.
func termSet(fd, b) {
    let rc = ioctl(toInt(fd), TCSETS, b)
    if rc == 0 { emit 1 }
    emit 0
}

// Switch fd to raw-ish mode: disable canonical input + echo, disable
// ISIG, VMIN=1 / VTIME=0, drop BRKINT/INLCR/IGNCR/ICRNL/IXON.
// Returns the saved termios (to hand to termRestore) — 0 on error.
func termRaw(fd) {
    let saved = termGet(fd)
    if saved == 0 { emit 0 }
    let raw = bufNew(60)
    let i = 0
    while i < 60 {
        bufSetByte(raw, i, bufGetByte(saved, i))
        i = i + 1
    }
    let lflag = bufGetDwordAt(raw, LFLAG_OFF)
    let drop = bitOr(bitOr(bitOr(bitOr(bitOr(ISIG, ICANON), ECHO), ECHOE), ECHOK), bitOr(ECHONL, IEXTEN))
    bufSetDwordAt(raw, LFLAG_OFF, bitAnd(lflag, bitNot(drop)))
    let iflag = bufGetDwordAt(raw, 0)
    let idrop = bitOr(bitOr(bitOr(bitOr(BRKINT, INLCR), IGNCR), bitOr(ICRNL, IXON)), 0)
    bufSetDwordAt(raw, 0, bitAnd(iflag, bitNot(idrop)))
    bufSetByte(raw, VMIN_OFF, 1)
    bufSetByte(raw, VTIME_OFF, 0)
    termSet(fd, raw)
    emit saved
}

// Switch the fd to "polling" mode: same flags as raw, but VMIN=0/VTIME=0 so
// read(0,...) returns immediately with whatever bytes (possibly 0) are
// available instead of blocking. Needed by any frame-based UI loop that
// must not stall between keystrokes.
func termPolling(fd, saved) {
    if saved == 0 { emit 0 }
    let raw = bufNew(60)
    let i = 0
    while i < 60 {
        bufSetByte(raw, i, bufGetByte(saved, i))
        i = i + 1
    }
    let lflag = bufGetDwordAt(raw, LFLAG_OFF)
    let drop = bitOr(bitOr(bitOr(bitOr(bitOr(ISIG, ICANON), ECHO), ECHOE), ECHOK), bitOr(ECHONL, IEXTEN))
    bufSetDwordAt(raw, LFLAG_OFF, bitAnd(lflag, bitNot(drop)))
    let iflag = bufGetDwordAt(raw, 0)
    let idrop = bitOr(bitOr(bitOr(bitOr(BRKINT, INLCR), IGNCR), bitOr(ICRNL, IXON)), 0)
    bufSetDwordAt(raw, 0, bitAnd(iflag, bitNot(idrop)))
    bufSetByte(raw, VMIN_OFF, 0)
    bufSetByte(raw, VTIME_OFF, 0)
    emit termSet(fd, raw)
}

// Restore a saved termios; 1 on success.
func termRestore(fd, saved) {
    if saved == 0 { emit 0 }
    emit termSet(fd, saved)
}

// "cols,rows" of the tty, "" on error.
func termWinsize(fd) {
    let w = bufNew(8)
    let rc = ioctl(toInt(fd), TIOCGWINSZ, w)
    if rc != 0 { emit "" }
    let rows = toInt(bufGetWordAt(w, 0))
    let cols = toInt(bufGetWordAt(w, 2))
    if cols <= 0 { cols = 80 }
    if rows <= 0 { rows = 24 }
    emit toStr(cols) + "," + toStr(rows)
}

// "" if fd is not a tty (ioctl fails), "1" otherwise.
func termIsTTY(fd) {
    let saved = termGet(fd)
    if saved == 0 { emit 0 }
    emit 1
}
