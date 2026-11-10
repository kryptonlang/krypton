// A3 enums — autoincrement int constants, resolved at compile time (FE), so they
// work on every backend. Pairs with A2 switch.
enum State { Idle, Running, Done, Error }
enum Color { Red, Green, Blue }

just run {
    if State.Idle != 0    { print("[FAIL] Idle=0"); exit("1") }
    if State.Error != 3   { print("[FAIL] Error=3"); exit("1") }
    if Color.Green != 1   { print("[FAIL] Green=1 (separate enum)"); exit("1") }
    let s = State.Running
    let r = ""
    switch s {
        case State.Idle:               r = "i"
        case State.Running:            r = "run"
        case State.Done, State.Error:  r = "end"
        default:                       r = "?"
    }
    if r != "run" { print("[FAIL] switch on enum"); exit("1") }
    if s == State.Running == 0 { print("[FAIL] enum =="); exit("1") }
    let e = State.Error
    let r2 = ""
    switch e { case State.Done, State.Error: r2 = "end"  default: r2 = "no" }
    if r2 != "end" { print("[FAIL] multi-value enum case"); exit("1") }
    print("[PASS] enums (autoincrement, separate enums, switch, ==, multi-value)")
}
