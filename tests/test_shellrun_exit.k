just run {
    let r1 = shellRun("exit 0")
    print("ok: " + r1)
    let r2 = shellRun("exit 7")
    print("err: " + r2)
    let r3 = shellRun("exit 42")
    print("err2: " + r3)
}
