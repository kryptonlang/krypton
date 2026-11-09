enum State { Idle, Running, Done, Error }
enum Color { Red, Green }
just run {
    let s = State.Running
    s = Color.Red
    let r = ""
    switch s {
        case State.Idle: r = "i"
    }
    print(r)
}
