func add(a, b) {
    emit a + b
}

just run {
    let x = add(3, 4)
    print(x)
    emit "ok"
}
