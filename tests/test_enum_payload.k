// A3 payload enums + destructuring pattern arms (switch and match).
// Payloads are raw word slots (int/text pointers), zero or more per case.
// Positive cases only; rejection fixtures live in
// tests/macos/fixtures/enum_exhaustive_payload_*.k.

enum Result { Ok(value), Err(message) }
enum Triple { Both(a, b), Alone(c) }

just run {
    let ok = Result.Ok(42)
    let err = Result.Err("boom")

    // switch with payload arms.
    let r = 0
    switch ok {
        case Result.Ok(v):  r = v + 100
        case Result.Err(m): r = 7
    }
    if r != 142 { kp("[FAIL] ok arm"); exit("1") }

    let r2 = ""
    switch err {
        case Result.Ok(v):  r2 = "no"
        case Result.Err(m): r2 = m
    }
    if r2 != "boom" { kp("[FAIL] err arm"); exit("1") }

    // match with pattern arms.
    let m = 0
    match ok {
        Result.Ok(v) { m = v + 1000 }
        Result.Err(x) { m = -1 }
    }
    if m != 1042 { kp("[FAIL] match arm"); exit("1") }

    // Inline-constructed scrutinee.
    let r3 = ""
    switch Result.Ok(7) {
        case Result.Ok(v):  r3 = "ok"
        case Result.Err(x): r3 = "err"
    }
    if r3 != "ok" { kp("[FAIL] inline constructor scrutinee"); exit("1") }

    // Multiple payload fields.
    let t = Triple.Both(3, 4)
    let prod = 0
    switch t {
        case Triple.Both(a, b): prod = a * b
        case Triple.Alone(c):    prod = c
    }
    if prod != 12 { kp("[FAIL] multi-payload arm"); exit("1") }

    // Mixed pattern + int-literal arms: both classify by value.
    let r4 = ""
    switch ok {
        case 0:              r4 = "zero"
        case Result.Err(m):  r4 = "err"
        default:             r4 = "other"
    }
    if r4 != "zero" { kp("[FAIL] mixed int-pattern arm"); exit("1") }

    // Constructors round-trip through plain member constants.
    let plain = Result.Ok()
    let tag = 0
    switch plain {
        case Result.Ok:  tag = 1
        case Result.Err: tag = 2
    }
    if tag != 1 { kp("[FAIL] zero-payload constructor"); exit("1") }

    // Exhaustive two-case switch compiles only because both are covered.
    let done = ""
    switch err {
        case Result.Ok(v):  done = "a"
        default:            done = "d"
    }
    if done != "d" { kp("[FAIL] default path"); exit("1") }

    kp("[PASS] payload enums (switch/match, multi-field, mixed, zero-payload)")
}
