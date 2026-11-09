enum Result { Ok(value), Err(message) }
just run {
    let r = Result.Ok()
    print("unreachable")
}
