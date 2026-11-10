// Draw an ASCII box around a line of text.

func repeat(ch, n) {
    let out = ""
    let i = 0
    while i < toInt(n) {
        out = out + ch
        i += 1
    }
    emit out
}

func box(text) {
    let w = len(text) + 4
    let bar = "+" + repeat("-", "" + (w - 2)) + "+"
    print(bar)
    print("| " + text + " |")
    print(bar)
}

just run {
    box("Hello, Krypton!")
    print("")
    box("Native compilation works")
    print("")
    box("a")
    print("")
    box("123456789012345678901234567890")
}
