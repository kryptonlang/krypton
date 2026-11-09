enum Result { Ok(value), Err(message) }
just run {
    let r = Result.Ok(1)
    match r {
        Result.Ok(v) { print(v) }
    }
}
