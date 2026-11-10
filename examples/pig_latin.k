// Pig Latin translator
// Converts English words to Pig Latin

func isVowel(ch) {
    if ch == "a" { emit 1 }
    if ch == "e" { emit 1 }
    if ch == "i" { emit 1 }
    if ch == "o" { emit 1 }
    if ch == "u" { emit 1 }
    if ch == "A" { emit 1 }
    if ch == "E" { emit 1 }
    if ch == "I" { emit 1 }
    if ch == "O" { emit 1 }
    if ch == "U" { emit 1 }
    emit 0
}

func toPigLatin(word) {
    if len(word) == 0 {
        emit ""
    }
    // If starts with vowel, add "way"
    if isVowel(word[0]) {
        emit word + "way"
    }
    // Move consonants before first vowel to end, add "ay"
    let i = 0
    while i < len(word) {
        if isVowel(word[i]) {
            let rest = substring(word, i, len(word))
            let moved = substring(word, 0, i)
            emit rest + moved + "ay"
        }
        i += 1
    }
    // No vowels found
    emit word + "ay"
}

func translateSentence(sentence) {
    let sb = sbNew()
    let wordBuf = sbNew()
    let first = 1
    let i = 0
    while i < len(sentence) {
        let ch = sentence[i]
        if ch == " " {
            let word = sbToString(wordBuf)
            if len(word) > 0 {
                if first == 0 {
                    sb = sbAppend(sb, " ")
                }
                sb = sbAppend(sb, toPigLatin(word))
                first = 0
            }
            wordBuf = sbNew()
        } else {
            wordBuf = sbAppend(wordBuf, ch)
        }
        i += 1
    }
    let lastWord = sbToString(wordBuf)
    if len(lastWord) > 0 {
        if first == 0 {
            sb = sbAppend(sb, " ")
        }
        sb = sbAppend(sb, toPigLatin(lastWord))
    }
    emit sbToString(sb)
}

just run {
    print("Pig Latin Translator")
    print("====================")
    print("")

    // Single words
    print("Word translations:")
    print("  hello  -> " + toPigLatin("hello"))
    print("  apple  -> " + toPigLatin("apple"))
    print("  string -> " + toPigLatin("string"))
    print("  igloo  -> " + toPigLatin("igloo"))
    print("  charm  -> " + toPigLatin("charm"))
    print("  three  -> " + toPigLatin("three"))
    print("")

    // Sentences
    print("Sentence translations:")
    let sentences = "hello world,the quick brown fox,krypton is awesome"
    let total = count(sentences)
    let i = 0
    while i < total {
        let s = split(sentences, i)
        print("  \"" + s + "\"")
        print("  -> \"" + translateSentence(s) + "\"")
        print("")
        i += 1
    }
    emit "ok"
}
