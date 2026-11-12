// Stub-size audit for compiler/linux_x86/elf.k — pure Krypton, no Python.
// Every runtime stub emits hex-byte text via emit*Code and declares its byte
// length in the matching *Size function. They must agree or every later
// stub/rodata vaddr shifts by the delta (kr_readfile declared 135 vs emitted
// 134, 2026-11-12), corrupting string literals in generated binaries.

func countSub(s, tok) {
    if tok == "" { emit 0 }
    let n = len(s)
    let m = len(tok)
    let i = 0
    let c = 0
    while i + m <= n {
        if substring(s, i, i + m) == tok {
            c += 1
            i = i + m
        } else {
            i += 1
        }
    }
    emit c
}

func countPad(body) {
    let total = 0
    let idx = 0
    while idx < len(body) {
        let p = indexOf(substring(body, idx, len(body)), "hexPad(")
        if p < 0 { emit total }
        let abs = idx + p + 7
        let q = abs
        while q < len(body) && body[q] != ")" { q += 1 }
        total += toInt(substring(body, abs, q))
        idx = q + 1
    }
    emit total
}

just run {
    let path = "compiler/linux_x86/elf.k"
    if argCount() >= 1 { path = arg(0) }
    let src = readFile(path)
    if src == "" {
        print("check_stub_sizes: cannot read " + path)
        exit(1)
    }

    // Parse funcs into flat records: delim "@" before name, "%" before body.
    let flat = ""
    let curName = ""
    let curBody = ""
    let inFunc = "0"
    let i = 0
    let n = len(src)
    let lineStart = 0
    while i <= n {
        if i == n || src[i] == "\n" {
            let line = substring(src, lineStart, i)
            if startsWith(line, "func ") {
                if inFunc == "1" {
                    flat = flat + "@" + curName + "%" + curBody
                }
                let rest = substring(line, 5, len(line))
                let end = indexOf(rest, "(")
                if end < 0 { end = len(rest) }
                curName = trim(substring(rest, 0, end))
                // Single-line func? `func name(...) { body }` all on one line.
                let openIdx = indexOf(rest, "{")
                let closeIdx = indexOf(rest, "}")
                if openIdx >= 0 && closeIdx > openIdx {
                    let body = substring(rest, openIdx + 1, closeIdx)
                    flat = flat + "@" + curName + "%" + body
                    inFunc = "0"
                    curBody = ""
                } else {
                    curBody = ""
                    inFunc = "1"
                }
            } else if inFunc == "1" {
                if trim(line) == "}" {
                    flat = flat + "@" + curName + "%" + curBody
                    inFunc = "0"
                    curBody = ""
                } else {
                    // strip // comments before counting hex markers
                    let cp = indexOf(line, "//")
                    if cp >= 0 { line = substring(line, 0, cp) }
                    if curBody == "" { curBody = line } else { curBody = curBody + "\n" + line }
                }
            }
            lineStart = i + 1
        }
        i += 1
    }

    // Pass 1: collect arg-fixed *Size declarations: sentinel-delimited entries.
    let declTable = ";"
    let pos = 0
    while pos < len(flat) {
        let start = pos + indexOf(substring(flat, pos, len(flat)), "@")
        if start < pos { break }
        let nameEnd = indexOf(substring(flat, start + 1, len(flat)), "%")
        if nameEnd < 0 { break }
        let name = substring(flat, start + 1, start + 1 + nameEnd)
        let bodyStart = start + 1 + nameEnd + 1
        let next = indexOf(substring(flat, bodyStart, len(flat)), "@")
        let bodyEnd = len(flat)
        if next >= 0 { bodyEnd = bodyStart + next }
        let body = substring(flat, bodyStart, bodyEnd)
        pos = bodyEnd

        if endsWith(name, "Size") && !contains(body, "if") {
            let emitPos = indexOf(body, "emit ")
            if emitPos >= 0 {
                let tail = substring(body, emitPos + 5, len(body))
                let j = 0
                while j < len(tail) && (isDigit(tail[j]) || tail[j] == "-") { j += 1 }
                let numText = substring(tail, 0, j)
                if numText != "" {
                    let base = substring(name, 0, len(name) - 4)
                    declTable = declTable + base + "=" + numText + ";"
                    if environ("KCC_DEBUG_STUBTABLE") == "1" {
                        print("decl: " + base + "=" + numText)
                    }
                }
            }
        }
    }

    // Pass 2: iterate funcs; for each emit*Code[Final], compute emitted bytes
    // and compare to the paired *Size declaration. Matches prefer the
    // *CodeFinal variant over the bare *Code variant when both exist for one
    // base — only one match is reported per Size declaration.
    let checked = 0
    let bad = 0
    let report = ""
    let matchedBases = ";"
    pos = 0
    while pos < len(flat) {
        let start = pos + indexOf(substring(flat, pos, len(flat)), "@")
        if start < pos { break }
        let nameEnd = indexOf(substring(flat, start + 1, len(flat)), "%")
        if nameEnd < 0 { break }
        let name = substring(flat, start + 1, start + 1 + nameEnd)
        let bodyStart = start + 1 + nameEnd + 1
        let next = indexOf(substring(flat, bodyStart, len(flat)), "@")
        let bodyEnd = len(flat)
        if next >= 0 { bodyEnd = bodyStart + next }
        let body = substring(flat, bodyStart, bodyEnd)
        pos = bodyEnd

        // Only emit*Code(Final) stubs
        if !startsWith(name, "emit") { continue }

        let actual = 0
        actual += countSub(body, "hexByte(") * 1
        actual += countSub(body, "hexDword(") * 4
        actual += countSub(body, "hexWord(") * 2
        actual += countSub(body, "hexQword(") * 8
        actual += countSub(body, "hexDwordVaddr(") * 4
        actual += countSub(body, "hexQwordVaddr(") * 8
        actual += countPad(body)

        // Normalize base: drop "emit" prefix, lower first remaining letter,
        // strip trailing "Code"/"CodeFinal".
        let base = substring(name, 4, len(name))
        if len(base) > 0 && base[0] >= "A" && base[0] <= "Z" {
            base = toLower(substring(base, 0, 1)) + substring(base, 1, len(base))
        }
        if endsWith(base, "CodeFinal") { base = substring(base, 0, len(base) - 9) }
        else if endsWith(base, "Code") { base = substring(base, 0, len(base) - 4) }
        else { continue }

        // Look up base in declTable with a leading-; sentinel
        let needle = ";" + base + "="
        let idx = indexOf(declTable, needle)
        if idx < 0 { continue }
        if indexOf(matchedBases, ";" + base + ";") >= 0 { continue }
        let valStart = idx + len(needle)
        let semi = indexOf(substring(declTable, valStart, len(declTable)), ";")
        if semi < 0 { semi = len(declTable) - valStart }
        let declared = toInt(substring(declTable, valStart, valStart + semi))

        checked += 1
        matchedBases = matchedBases + base + ";"
        if actual != declared {
            bad += 1
            report = report + "MISMATCH " + name + " (" + base + "Size): declared " + declared + " vs emitted " + actual + "\n"
        }
        if environ("KCC_DEBUG_STUBS") == "1" {
            print("match: " + name + " -> " + base + "Size (" + declared + ") actual=" + actual)
        }
    }

    if report != "" { print(report) }
    print("checked " + checked + " stubs; " + bad + " mismatch(es)")
    if bad > 0 { exit(1) }
    print("[PASS] stub-size audit")
}
