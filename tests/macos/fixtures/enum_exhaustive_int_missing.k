enum State { Idle, Running, Done, Error }
just run {
    let s = State.Running
    let r = ""
    switch s {
        case 0: r = "i"
        case 1: r = "run"
    }
    print(r)
}
