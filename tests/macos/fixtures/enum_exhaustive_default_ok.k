enum State { Idle, Running, Done, Error }
just run {
    let s = State.Running
    let r = ""
    switch s {
        case State.Idle: r = "i"
        default:         r = "other"
    }
    print(r)
}
