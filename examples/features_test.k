func add(a, b) {
    emit a + b
}

func greet(name) {
    emit "Hello, " + name
}

just run {
    // Test function calls
    let x = add(3, 4)
    print(x)

    // Test string ops
    let msg = greet("Krypton")
    print(msg)

    // Test while loop
    let i = 0
    while i < 5 {
        print(i)
        i += 1
    }

    // Test if/else if/else
    let val = 42
    if val == 42 {
        print("found it")
    } else if val == 0 {
        print("zero")
    } else {
        print("other")
    }

    // Test string indexing
    let s = "abc"
    print(s[0])
    print(s[1])
    print(s[2])

    // Test comparisons
    if 10 > 5 {
        print("10 > 5")
    }

    // Test split and toInt
    let pair = "hello,world"
    let first = split(pair, 0)
    let second = split(pair, 1)
    print(first)
    print(second)

    // Test startsWith
    if startsWith("hello world", "hello") {
        print("starts with hello")
    }

    // Test len
    print(len("test"))

    emit "ok"
}
