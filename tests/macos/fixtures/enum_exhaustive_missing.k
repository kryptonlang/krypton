enum State { Idle, Running, Done, Error }
just run {
    let s = State.Running
    let r = ""
    switch s {
        case State.Idle:    r = "i"
        case State.Running: r = "run"
        case State.Done:    r = "done"
    }
    print(r)
}
