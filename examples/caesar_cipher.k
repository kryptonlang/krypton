// Caesar cipher - encrypt and decrypt messages
// Shifts each letter by a given number of positions

func encryptChar(ch, shift) {
    let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let lower = "abcdefghijklmnopqrstuvwxyz"

    // Check uppercase
    let i = 0
    while i < 26 {
        if ch == upper[i] {
            let newIdx = (i + shift) % 26
            emit upper[newIdx]
        }
        i += 1
    }

    // Check lowercase
    i = 0
    while i < 26 {
        if ch == lower[i] {
            let newIdx = (i + shift) % 26
            emit lower[newIdx]
        }
        i += 1
    }

    // Non-letter characters pass through
    emit ch
}

func encrypt(text, shift) {
    let sb = sbNew()
    let i = 0
    while i < len(text) {
        sb = sbAppend(sb, encryptChar(text[i], shift))
        i += 1
    }
    emit sbToString(sb)
}

func decrypt(text, shift) {
    emit encrypt(text, 26 - shift)
}

just run {
    print("Caesar Cipher")
    print("=============")

    let message = "Hello World from Krypton"
    let shift = 3

    print("Original:  " + message)
    let encrypted = encrypt(message, shift)
    print("Encrypted: " + encrypted + " (shift=" + shift + ")")
    let decrypted = decrypt(encrypted, shift)
    print("Decrypted: " + decrypted)
    print("")

    // Try all shifts
    print("All possible decryptions of '" + encrypted + "':")
    let s = 0
    while s < 26 {
        print("  shift " + s + ": " + decrypt(encrypted, s))
        s = s + 1
    }
    emit "ok"
}
