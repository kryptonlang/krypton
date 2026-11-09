enum State { Idle, Running, Done, Error }
enum Result { Ok(value), Err(message) }
just run {
    let s = State.Running
    let r = 0
    switch s {
        case Result.Ok(v): r = v
        case State.Idle:   r = 0
        case State.Running: r = 1
        case State.Done:   r = 2
        case State.Error:  r = 3
    }
    print(r)
}
