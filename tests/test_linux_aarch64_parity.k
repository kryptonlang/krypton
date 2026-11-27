// Linux AArch64 native-backend parity regressions.

func expect(label, ok) {
    if ok { print("[PASS] " + label) }
    else { print("[FAIL] " + label) }
}

just run {
    expect("signed atoi", toInt("-42") == -42)
    expect("parseInt alias", parseInt("13") == 13)
    expect("numeric subtraction", "10" - "3" == 7)
    expect("numeric multiplication", "6" * "7" == 42)
    expect("numeric division", "20" / "4" == 5)
    expect("numeric modulo", "20" % 3 == 2)
    expect("bitwise coercion", bitAnd("12", "10") == 8 && bitOr("12", "10") == 14)
    expect("shift coercion", shl("3", "2") == 12 && shr("12", "2") == 3)
    expect("numeric builtins", abs("-9") == 9 && pow("2", "5") == 32)
    expect("min max coercion", min("9", "4") == 4 && max("9", "4") == 9)
    expect("range coercion", range("2", "5") == "2,3,4")
    expect("repeat alias", repeat("ab", "3") == "ababab")
    expect("hex alias", hex("255") == "ff")
    expect("pad coercion", padLeft("7", "3", "0") == "007")
    expect("smart len", len(123) == 3)
    expect("charAt coercion", charAt("abc", "1") == "b")
    expect("substring coercion", substring("abcdef", "2", "5") == "cde")
    expect("substring bounds", substring("abc", -4, 99) == "abc")
    expect("forced concat", `{1}{2}` == "12")
    expect("numeric equality", "13" == 13)
    expect("ordered numeric compare", 2 < "10")
    expect("mixed compare safety", 1 < "x")

    let sb = sbNew()
    sb = sbAppend(sb, 12)
    sb = sbAppend(sb, "x")
    expect("builder integer append", sbToString(sb) == "12x")
    expect("shell exit text", shellRun("exit 7") == "7")
    expect("missing readFile", readFile("/definitely/not/a/krypton/file") == "")

    expect("fformat half away", fformat(2.5, 0) == "3")
    expect("float equality", feq(1.0, 1.0) == 1 && feq(1.0, 2.0) == 0)
    expect("float ordering", fgt(2.0, 1.0) == 1 && fgt(1.0, 2.0) == 0)
    let nan = 0.0 / 0.0
    expect("float NaN predicates", feq(nan, nan) == 0 && flt(nan, 1.0) == 0 && fgt(nan, 1.0) == 0)

    let g0 = gcMark()
    let g1 = gcSweep()
    let g2 = gcReset()
    let g3 = gcCheckpoint()
    let g4 = gcRestore(g3)
    let g5 = gcSlabCount()
    let g6 = gcSlabBytes()
    gcSetThreshold("10")
    gcSetLimit("100")
    expect("GC stack safety", g0 == 0 && g1 == 0 && g2 == 0 && g3 == 0 && g4 == 0 && g5 == 0 && g6 == 0)
    expect("GC limit coercion", gcLimit() == 100)

    let p = bufNew(16)
    bufSetDwordAt(p, 0, 305419896)
    expect("big endian load", bufGetDwordAtBE(p, 0) == 2018915346)
    expect("buffer aliases", bufGetDword(p) == 305419896)
    bufSetDword(p, 123)
    expect("buffer setter alias", bufGetDword(p) == 123)
    bufSetQwordAt(p, 8, 456)
    expect("pointer identity", ptrEq(p, p) == 1 && ptrEq(p, bufNew(8)) == 0)
    expect("pointer indexing", ptrDeref(ptrIndex(p, "1")) == 456)
    let h = handleOut()
    bufSetQwordAt(h, 0, 789)
    expect("handle interop", handleGet(h) == 789 && ptrEq(toHandle(handleInt(h)), h))

    expect("string helpers", strReverse("abc") == "cba" && isSpace(" ") == 1 && isSpace("x") == 0)
    let r = random(7)
    expect("random range", r >= 0 && r < 7)
    expect("timestamp", toInt(timestamp()) > 0)
    expect("barriers", pause() == 0 && mfence() == 0 && lfence() == 0 && sfence() == 0)
}
