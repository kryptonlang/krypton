enum Mixed { Ok(value), Bare }
just run {
    let r = Mixed.Ok(1)
    switch r {
        case Mixed.Ok(v): print(v)
        case Mixed.Bare: print("bare")
    }
}
