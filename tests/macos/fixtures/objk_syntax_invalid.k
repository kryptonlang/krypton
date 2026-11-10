objk protocol Broken {
    require value(amount) -> int
}

just run { print("[FAIL] expected syntax rejection") }
