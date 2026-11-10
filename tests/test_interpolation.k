// Test: String interpolation with backtick strings

just run {
    let name = "Krypton"
    let n = "42"

    // Basic interpolation
    let s1 = `Hello {name}`
    if s1 == "Hello Krypton" { print("PASS basic interp") } else { print("FAIL basic interp: " + s1) }

    // Multiple expressions
    let x = "3"
    let y = "4"
    let s2 = `({x}, {y})`
    if s2 == "(3, 4)" { print("PASS multi interp") } else { print("FAIL multi interp: " + s2) }

    // Interpolation with surrounding text
    let s3 = `value is {n} items`
    if s3 == "value is 42 items" { print("PASS surrounding text") } else { print("FAIL surrounding text: " + s3) }

    // Interpolation at start
    let s4 = `{name} is great`
    if s4 == "Krypton is great" { print("PASS interp at start") } else { print("FAIL interp at start: " + s4) }

    // Interpolation at end
    let s5 = `Hello {name}`
    if s5 == "Hello Krypton" { print("PASS interp at end") } else { print("FAIL interp at end: " + s5) }

    print("interpolation tests done")
}
