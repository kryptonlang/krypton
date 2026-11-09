enum State { Idle, Running, Done }
just run {
    let s = State.Running
    let r = ""
    switch s {
        case 0x0: r = "i"
        case 0x1: r = "run"
        case 0x2: r = "done"
    }
    print(r)
}
