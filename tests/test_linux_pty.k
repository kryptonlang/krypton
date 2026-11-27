// Linux native PTY + process-control smoke test.
just run {
    let master = ptyMaster("/dev/ptmx")
    if master < 0 { print("[FAIL] ptyMaster")  exit(1) }
    let slave = ptySlaveName(master)
    if startsWith(slave, "/dev/pts/") != 1 { print("[FAIL] ptySlaveName")  exit(1) }
    if ptySetSize(master, 24, 80) != 0 { print("[FAIL] ptySetSize")  exit(1) }
    let ws = bufNew(8)
    if ioctl(master, 21523, ws) != 0 { print("[FAIL] ioctl TIOCGWINSZ")  exit(1) }
    if bufGetWordAt(ws, 0) != 24 || bufGetWordAt(ws, 2) != 80 { print("[FAIL] winsize readback")  exit(1) }
    let pid = ptyForkExec(slave, "/bin/sh")
    if pid <= 0 { print("[FAIL] ptyForkExec")  exit(1) }
    sleepUs(0, 100000)
    fdWrite(master, "echo pty_ok\n", 12)
    sleepUs(0, 200000)
    let out = fdRead(master, 256)
    if contains(out, "pty_ok") != 1 { print("[FAIL] pty read")  exit(1) }
    fdWrite(master, "exit\n", 5)
    let reaped = 0
    let spins = 0
    while reaped == 0 && spins < 50 {
        sleepUs(0, 20000)
        reaped = waitChild(pid)
        spins += 1
    }
    if reaped <= 0 { print("[FAIL] waitChild")  exit(1) }
    if procAlive(pid) != 0 { print("[FAIL] procAlive")  exit(1) }
    fdClose(master)
    print("[PASS] Linux PTY + process")
}
