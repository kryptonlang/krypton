// Tutorial 17: Entry blocks with go
// 'go run' is an alias for the executable's 'just run' entry block.

go run {
    func square(n) { emit n * n }
    func cube(n) { emit n * n * n }

    print("=== Math Demo ===")
    let i = 1
    while i <= 5 {
        print("" + i + ": square=" + square(i) + " cube=" + cube(i))
        i = i + 1
    }
}
