// Test exec: capture child stdout.
just run {
    print("before")
    let out = exec("echo captured")
    print("captured = [" + out + "]")
    print("after")
}
