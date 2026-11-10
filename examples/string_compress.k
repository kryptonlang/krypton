// String compression using run-length encoding
// "AAABBBCCCA" -> "3A3B3C1A"

func compress(s) {
    if len(s) == 0 {
        emit ""
    }
    let sb = sbNew()
    let i = 0
    while i < len(s) {
        let ch = s[i]
        let cnt = 1
        while i + cnt < len(s) {
            if s[i + cnt] != ch {
                break
            }
            cnt += 1
        }
        sb = sbAppend(sb, "" + cnt)
        sb = sbAppend(sb, ch)
        i = i + cnt
    }
    emit sbToString(sb)
}

func decompress(s) {
    let sb = sbNew()
    let i = 0
    while i < len(s) {
        // Read number
        let numStr = ""
        while i < len(s) {
            let ch = s[i]
            if ch >= "0" {
                if ch <= "9" {
                    numStr = numStr + ch
                    i += 1
                } else {
                    break
                }
            } else {
                break
            }
        }
        // Read character
        if i < len(s) {
            let ch = s[i]
            let cnt = toInt(numStr)
            let j = 0
            while j < cnt {
                sb = sbAppend(sb, ch)
                j += 1
            }
            i += 1
        }
    }
    emit sbToString(sb)
}

just run {
    print("Run-Length Encoding")
    print("===================")
    print("")

    let tests = "AAABBBCCCA,AABBBCCCC,ABCDE,AAAAAAA,AABBCCDD,ABABABAB"
    let total = count(tests)
    let i = 0
    while i < total {
        let original = split(tests, i)
        let compressed = compress(original)
        let decompressed = decompress(compressed)
        let ratio = (len(compressed) * 100) / len(original)
        print("  Original:     " + original)
        print("  Compressed:   " + compressed)
        print("  Decompressed: " + decompressed)
        print("  Ratio:        " + ratio + "% of original")
        let matched = "OK"
        if original != decompressed {
            matched = "MISMATCH"
        }
        print("  Verify:       " + matched)
        print("")
        i += 1
    }
    emit "ok"
}
