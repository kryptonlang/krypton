just run {
    let a = 10
    let b = 5
    let li = toInt(a)
    let ri = toInt(b)
    print("a=" + a)
    print("b=" + b)
    print("li=" + li)
    print("ri=" + ri)
    let numL = li + "" == a
    let numR = ri + "" == b
    print("numL=" + numL)
    print("numR=" + numR)
    if li > ri {
        print("li > ri")
    }
    if a > b {
        print("a > b")
    }
    emit "ok"
}
