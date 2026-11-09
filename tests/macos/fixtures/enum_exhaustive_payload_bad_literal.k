enum Result { Ok(value), Err(message) }
just run {
    let r = Result.Ok(1)
    switch r {
        case Result.Ok(v + 1): print("x")
        case Result.Err(m): print("e")
    }
}
