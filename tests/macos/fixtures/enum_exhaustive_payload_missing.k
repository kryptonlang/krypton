enum Result { Ok(value), Err(message) }
just run {
    let r = Result.Ok(1)
    let out = 0
    switch r {
        case Result.Ok(v): out = v
    }
    print(out)
}
