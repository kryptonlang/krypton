// Test: try/catch/throw exception handling

func mayThrow(x) {
    if x == "0" {
        throw "zero error"
    }
    emit "ok"
}

just run {
    // Basic throw and catch
    let caught = "no"
    try {
        throw "test error"
    } catch e {
        caught = e
    }
    if caught == "test error" { print("PASS basic throw") } else { print("FAIL basic throw") }

    // No throw - catch skipped
    let ran = "no"
    try {
        ran = "yes"
    } catch e {
        ran = "caught"
    }
    if ran == "yes" { print("PASS no throw") } else { print("FAIL no throw") }

    // Throw from function
    let result = ""
    try {
        result = mayThrow("0")
    } catch e {
        result = "caught: " + e
    }
    if result == "caught: zero error" { print("PASS throw from func") } else { print("FAIL throw from func: " + result) }

    // Successful function call in try
    let r2 = ""
    try {
        r2 = mayThrow("1")
    } catch e {
        r2 = "error"
    }
    if r2 == "ok" { print("PASS success in try") } else { print("FAIL success in try") }

    // Nested try/catch
    let outer = ""
    try {
        try {
            throw "inner"
        } catch e {
            throw "rethrown"
        }
    } catch e {
        outer = e
    }
    if outer == "rethrown" { print("PASS nested+rethrow") } else { print("FAIL nested+rethrow") }

    // throw as function
    let tf = ""
    try {
        throw("func form")
    } catch e {
        tf = e
    }
    if tf == "func form" { print("PASS throw func form") } else { print("FAIL throw func form") }

    print("try/catch tests done")
}
