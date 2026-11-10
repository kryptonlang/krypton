// Permutations generator
// Generates all permutations of a string

func permute(prefix, remaining) {
    if len(remaining) == 0 {
        print(prefix)
    } else {
        let i = 0
        while i < len(remaining) {
            let ch = remaining[i]
            // Use sb for both rest and prefix+ch — once any of these become
            // digit-only strings, the spec's numeric `+` rule kicks in and we
            // get arithmetic (e.g. substring "2" + substring "4" → 6) instead
            // of concat. sb forces string concat at every step.
            let restSb = sbNew()
            restSb = sbAppend(restSb, substring(remaining, 0, i))
            restSb = sbAppend(restSb, substring(remaining, i + 1, len(remaining)))
            let rest = sbToString(restSb)
            let sb = sbNew()
            sb = sbAppend(sb, prefix)
            sb = sbAppend(sb, ch)
            permute(sbToString(sb), rest)
            i += 1
        }
    }
}

just run {
    let s = "ABC"
    print("Permutations of '" + s + "':")
    permute("", s)

    print("")
    let s2 = "1234"
    print("Permutations of '" + s2 + "':")
    permute("", s2)
}
