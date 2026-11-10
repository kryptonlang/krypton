// Test: Struct declaration, instantiation, field access, field assignment

struct Vec {
    let x
    let y
    let z
}

struct Box {
    let label
    let value
}

just run {
    // Constructor
    let v = Vec()
    v.x = "1"
    v.y = "2"
    v.z = "3"
    if v.x == "1" { print("PASS constructor+assign") } else { print("FAIL constructor+assign") }
    if v.z == "3" { print("PASS multi-field") } else { print("FAIL multi-field") }

    // Struct literal
    let v2 = Vec { x: "10", y: "20", z: "30" }
    if v2.x == "10" { print("PASS literal x") } else { print("FAIL literal x") }
    if v2.y == "20" { print("PASS literal y") } else { print("FAIL literal y") }
    if v2.z == "30" { print("PASS literal z") } else { print("FAIL literal z") }

    // Field update
    v2.x = "99"
    if v2.x == "99" { print("PASS field update") } else { print("FAIL field update") }

    // Struct in function (nested func decl, hoisted by compile.k)
    func boxVal(b) { emit b.value }
    let b = Box { label: "score", value: "42" }
    if boxVal(b) == "42" { print("PASS struct in func") } else { print("FAIL struct in func") }

    // Dynamic struct
    // Per spec, setField returns the updated env; assign back so the
    // pure-functional native runtime sees the additions. (The C runtime
    // also mutates in place, so reassignment is harmless there.)
    let obj = structNew()
    obj = setField(obj, "a", "hello")
    obj = setField(obj, "b", "world")
    if getField(obj, "a") == "hello" { print("PASS dynamic get") } else { print("FAIL dynamic get") }
    if hasField(obj, "b") == "1" { print("PASS hasField") } else { print("FAIL hasField") }
    if hasField(obj, "z") == "0" { print("PASS hasField missing") } else { print("FAIL hasField missing") }
    let fields = structFields(obj)
    if contains(fields, "a") { print("PASS structFields") } else { print("FAIL structFields") }

    print("struct tests done")
}
