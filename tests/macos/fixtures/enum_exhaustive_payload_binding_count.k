enum Triple { Both(a, b), Alone(c) }
just run {
    let t = Triple.Both(1, 2)
    switch t {
        case Triple.Both(a): print(a)
        case Triple.Alone(c): print(c)
    }
}
