// hello_modules.k — simplest possible import example

module hello

import "k:math_utils"
import "k:string_utils"

just run {
    print("=== Hello Modules ===")

    // From math_utils.k
    print(`isPrime(7) = {isPrime(7)}`)
    print(`factorial(6) = {factorial(6)}`)
    print(`gcd(24, 36) = {gcd(24, 36)}`)

    // From string_utils.k
    let s = "  hello krypton  "
    print(`trimmed: "{trim(s)}"`)
    print(`upper: {toUpper(trim(s))}`)
    print(`reversed: {reverse("krypton")}`)
}
