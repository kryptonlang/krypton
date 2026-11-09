#!/usr/bin/env kr
// check_enum_exhaustive.ks — compile-time exhaustiveness diagnostics for
// A2 switch / match on A3 enums.
//
// Uses the checked-out macho arm64 frontend plus the repo's macho_host to
// compile each fixture to a binary; success/ABI is then observed via its exit
// status. NOTE: the exhaustiveness pass lives in compiler/compile.k; it only
// exists once the checked-out frontend has been rebuilt from source. Until
// then (stale prebuilt frontend in-tree) the reject fixtures fail open with
// rc=0. Rebuild the frontend per HANDOFF-enum-exhaustive.md first.
//
// Override the frontend explicitly with KCC_FRONTEND=/path/to/kcc-arm64.

import "k:env"

func q(s) {
    let quote = fromCharCode(39)
    emit quote + replace(s, quote, quote + "\\" + quote + quote) + quote
}

func frontend(root) {
    let fe = environ("KCC_FRONTEND")
    if fe == "" { emit root + "/compiler/macos_arm64/kcc-arm64" }
    emit fe
}

func compileFixture(root, source, binary, log) {
    let fe = frontend(root)
    let kir = binary + ".kir"
    let ir = shellRun("KRYPTON_ROOT=" + q(root) + " " + q(fe) + " --ir " + q(source) + " >" + q(kir) + " 2>" + q(log))
    if ir != "0" { emit "ir" }
    let code = shellRun(q(root + "/compiler/macos_arm64/macho_host") + " --ir " + q(kir) + " " + q(binary) + " >>" + q(log) + " 2>&1")
    if code != "0" { emit "code" }
    emit "ok"
}

func syntaxReject(root, source, expected, log) {
    let binary = log + ".bin"
    let stage = compileFixture(root, source, binary, log)
    if stage == "ok" {
        kp("FAIL no diagnostic for " + source)
        kp(readFile(log))
        exit("1")
    }
    if !contains(readFile(log), expected) {
        kp("FAIL wrong diagnostic for " + source)
        kp(readFile(log))
        exit("1")
    }
    kp("OK rejects " + source)
}

func syntaxAccept(root, source, log) {
    let binary = log + ".bin"
    let stage = compileFixture(root, source, binary, log)
    if stage != "ok" {
        kp("FAIL compile " + source)
        kp(readFile(log))
        exit("1")
    }
    kp("OK accepts " + source)
}

just run {
    if trim(exec("uname -s")) != "Darwin" {
        kp("SKIP macOS enum exhaustiveness checks")
        exit("0")
    }
    let root = trim(exec("pwd"))
    let work = trim(exec("mktemp -d /tmp/check_enum_exh.XXXXXX"))
    if work == "" { kp("FAIL temporary directory"); exit("1") }
    let log = work + "/run.log"
    syntaxReject(root, "tests/macos/fixtures/enum_exhaustive_missing.k",
        "non-exhaustive switch on State", log)
    syntaxReject(root, "tests/macos/fixtures/enum_exhaustive_int_missing.k",
        "non-exhaustive switch on State", log)
    syntaxReject(root, "tests/macos/fixtures/enum_exhaustive_match_missing.k",
        "non-exhaustive switch on State", log)
    syntaxReject(root, "tests/macos/fixtures/enum_exhaustive_payload_missing.k",
        "non-exhaustive switch on Result", log)
    syntaxReject(root, "tests/macos/fixtures/enum_exhaustive_payload_match_missing.k",
        "non-exhaustive switch on Result", log)
    syntaxReject(root, "tests/macos/fixtures/enum_exhaustive_payload_binding_count.k",
        "expects 2 binding(s)", log)
    syntaxReject(root, "tests/macos/fixtures/enum_exhaustive_payload_bad_literal.k",
        "bindings must be bare identifiers", log)
    syntaxReject(root, "tests/macos/fixtures/enum_exhaustive_payload_cross_enum.k",
        "does not match switch on State", log)
    syntaxReject(root, "tests/macos/fixtures/enum_mixed_payload_plain.k",
        "mixes payload and plain cases", log)
    syntaxReject(root, "tests/macos/fixtures/enum_constructor_arity.k",
        "expects 1 argument(s)", log)
    syntaxReject(root, "tests/macos/fixtures/enum_duplicate_member.k",
        "duplicate member in enum", log)
    syntaxAccept(root, "tests/macos/fixtures/enum_exhaustive_default_ok.k", log)
    syntaxAccept(root, "tests/macos/fixtures/enum_exhaustive_else_ok.k", log)
    syntaxAccept(root, "tests/macos/fixtures/enum_exhaustive_ambiguous.k", log)
    syntaxAccept(root, "tests/macos/fixtures/enum_exhaustive_int_full.k", log)
    syntaxAccept(root, "tests/macos/fixtures/enum_exhaustive_hex_ok.k", log)
    kp("OK enum exhaustiveness checks")
}
