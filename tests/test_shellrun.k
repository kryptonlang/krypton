// Test shellRun: spawn cmd.exe /C echo, wait, get "0".
just run {
    print("before")
    let r = shellRun("echo from-shell")
    print("returned: " + r)
    print("after")
}
