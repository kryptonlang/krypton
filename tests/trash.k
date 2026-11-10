just run {
    let i = 0
    let acc = ""
    while i < 50000 {
        acc = acc + "x"
        if i % 5000 == 0 {
            print("iter " + i + " size=" + len(acc))
        }
        i += 1
    }
    print("done size=" + len(acc))
}