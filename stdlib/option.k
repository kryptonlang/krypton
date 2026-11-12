// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// option.k — Option type for nullable values
// An Option is either "some:VALUE" or "none"

module option

func optSome(val) {
    emit "some:" + val
}

func optNone() {
    emit "none"
}

func isSome(opt) {
    emit startsWith(opt, "some:")
}

func isNone(opt) {
    emit opt == "none"
}

func optUnwrap(opt) {
    if startsWith(opt, "some:") {
        emit substring(opt, 5, len(opt))
    }
    print("ERROR: optUnwrap called on None")
    exit(1)
    emit ""
}

func optUnwrapOr(opt, fallback) {
    if startsWith(opt, "some:") {
        emit substring(opt, 5, len(opt))
    }
    emit fallback
}

func optMap(opt, val) {
    if opt == "none" { emit "none" }
    emit optSome(val)
}
