enum State { Idle, Running, Done, Error }
just run {
    let s = State.Running
    match s {
        State.Idle { print("i") }
        State.Running { print("run") }
        State.Done { print("done") }
    }
}
