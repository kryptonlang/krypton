// String reversal examples
// Multiple approaches to reversing a string

func reverseSimple(s) {
    let sb = sbNew()
    let i = len(s) - 1
    while i >= 0 {
        sb = sbAppend(sb, s[i])
        i -= 1
    }
    emit sbToString(sb)
}

func reverseWords(sentence) {
    // Split by spaces, reverse order
    let words = ""
    let sb = sbNew()
    let i = 0
    while i < len(sentence) {
        if sentence[i] == " " {
            let word = sbToString(sb)
            if len(word) > 0 {
                if words == "" {
                    words = word
                } else {
                    words = words + "," + word
                }
            }
            sb = sbNew()
        } else {
            sb = sbAppend(sb, sentence[i])
        }
        i += 1
    }
    let lastWord = sbToString(sb)
    if len(lastWord) > 0 {
        if words == "" {
            words = lastWord
        } else {
            words = words + "," + lastWord
        }
    }

    // Reverse and rejoin
    let result = sbNew()
    let wCount = count(words)
    let j = wCount - 1
    while j >= 0 {
        if j < wCount - 1 {
            result = sbAppend(result, " ")
        }
        result = sbAppend(result, split(words, j))
        j -= 1
    }
    emit sbToString(result)
}

func reverseEachWord(sentence) {
    let sb = sbNew()
    let wordBuf = sbNew()
    let i = 0
    while i < len(sentence) {
        if sentence[i] == " " {
            sb = sbAppend(sb, reverseSimple(sbToString(wordBuf)))
            sb = sbAppend(sb, " ")
            wordBuf = sbNew()
        } else {
            wordBuf = sbAppend(wordBuf, sentence[i])
        }
        i += 1
    }
    sb = sbAppend(sb, reverseSimple(sbToString(wordBuf)))
    emit sbToString(sb)
}

just run {
    print("String Reversal Examples")
    print("========================")

    let text = "Hello World"
    print("Original:       " + text)
    print("Reversed:       " + reverseSimple(text))
    print("Words reversed: " + reverseWords(text))
    print("Each word rev:  " + reverseEachWord(text))
    print("")

    let text2 = "Krypton is a programming language"
    print("Original:       " + text2)
    print("Reversed:       " + reverseSimple(text2))
    print("Words reversed: " + reverseWords(text2))
    print("Each word rev:  " + reverseEachWord(text2))
    emit "ok"
}
