just run {
    let val = 42
    print("val=" + val)
    if val == 42 {
        print("found it")
    }
    if val == 42 {
        print("match")
    } else {
        print("no match")
    }
    if val == 42 {
        print("yes")
    } else if val == 0 {
        print("zero")
    } else {
        print("other")
    }
    emit "ok"
}
