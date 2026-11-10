// A2/A3 enum exhaustiveness checking for switch and match.
// Positive cases only — the compile-time rejection fixtures live in
// tests/macos/fixtures/enum_exhaustive_*.k and are exercised by
// scripts/check_enum_exhaustive.ks.

enum State { Idle, Running, Done, Error }
enum Color { Red, Green, Blue }

just run {
    // Full enum coverage, member arms.
    let s = State.Running
    let r = ""
    switch s {
        case State.Idle:               r = "i"
        case State.Running:            r = "run"
        case State.Done, State.Error:  r = "end"
    }
    if r != "run" { print("[FAIL] full member coverage"); exit("1") }

    // Full coverage through int literals.
    let r1 = ""
    switch s {
        case 0: r1 = "0"
        case 1: r1 = "1"
        case 2: r1 = "2"
        case 3: r1 = "3"
    }
    if r1 != "1" { print("[FAIL] int literal coverage"); exit("1") }

    // Direct enum scrutinee.
    let r2 = ""
    switch State.Error {
        case State.Idle:  r2 = "a"
        case State.Running: r2 = "b"
        case State.Done:  r2 = "c"
        case State.Error: r2 = "d"
    }
    if r2 != "d" { print("[FAIL] direct enum scrutinee"); exit("1") }

    // default: arm makes any subset legal.
    let r3 = ""
    switch Color.Blue {
        case Color.Red: r3 = "red"
        default:        r3 = "other"
    }
    if r3 != "other" { print("[FAIL] default arm"); exit("1") }

    // match statement with else is accepted.
    match Color.Green {
        Color.Red { r3 = "red" }
        else { r3 = "match-other" }
    }
    if r3 != "match-other" { print("[FAIL] match else arm"); exit("1") }

    // match statement with full coverage.
    match State.Idle {
        State.Idle { r3 = "was-idle" }
        State.Running { r3 = "was-running" }
        State.Done { r3 = "was-done" }
        State.Error { r3 = "was-error" }
    }
    if r3 != "was-idle" { print("[FAIL] match full coverage"); exit("1") }

    // A var assigned two different enums is not statically checkable; the
    // switch compiles as before.
    let u = State.Done
    u = Color.Blue
    let r4 = "kept"
    switch u {
        case State.Idle: r4 = "changed"
    }
    if r4 != "kept" { print("[FAIL] ambiguous var should compile and run"); exit("1") }

    // Hex literal coverage.
    let r5 = ""
    switch s {
        case 0x0: r5 = "i"
        case 0x1: r5 = "run"
        case 0x2: r5 = "done"
        case 0x3: r5 = "error"
    }
    if r5 != "run" { print("[FAIL] hex literal coverage"); exit("1") }

    print("[PASS] enum exhaustiveness (member, int, direct, default, match, ambiguous, hex)")
}
