#!/usr/bin/env kr
// check_import_resolution.ks — import resolution is a hard-fail compiler step.
//
// Before the fix for t3m3d/krypton#7, an unresolvable import was silently
// dropped: the frontend emitted IR with the imported FUNCs missing, and the
// failure only surfaced much later as "unknown function '...' called from
// '__main__'" from the codegen, with no diagnostic at the import site.
//
// Now: any unresolvable or empty import (direct, transitive, Odin-style k:
// prefix, or jxt { k "..." }) is a fatal compiler error with a clear
// "unresolvable import" message on stderr. This test pins that behavior.
//
// NOTE: like check_enum_exhaustive.ks, this only passes once the checked-out
// frontend has been rebuilt from compiler/compile.k (the import-resolution
// pass lives there). Override the frontend explicitly with KCC_FRONTEND.
//
//   KCC_FRONTEND=/path/to/kcc-arm64 ./scripts/check_import_resolution.ks
//
// Differences in this machine's toolchain (readFile() of a missing path
// corrupts fd state so later fd-2 writes silently no-op) are handled by the
// fix itself: existence is probed with the shell before readFile().

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

func syntaxReject(root, source, expected, log) {
    let kir = log + ".kir"
    let rc = shellRun("KRYPTON_ROOT=" + q(root) + " " + q(frontend(root)) + " --ir " + q(source) + " >" + q(kir) + " 2>" + q(log))
    if rc == "0" {
        print("FAIL compiled but should reject: " + source)
        exit("1")
    }
    if !contains(readFile(log), expected) {
        print("FAIL wrong diagnostic for " + source)
        print(readFile(log))
        exit("1")
    }
    print("OK rejects " + source)
}

func syntaxAccept(root, source, log) {
    let kir = log + ".kir"
    let rc = shellRun("KRYPTON_ROOT=" + q(root) + " " + q(frontend(root)) + " --ir " + q(source) + " >" + q(kir) + " 2>" + q(log))
    if rc != "0" {
        print("FAIL could not compile: " + source)
        print(readFile(log))
        exit("1")
    }
    print("OK accepts " + source)
}

just run {
    if trim(exec("uname -s")) != "Darwin" {
        print("SKIP macOS import resolution checks")
        exit("0")
    }
    let root = trim(exec("pwd"))
    let work = trim(exec("mktemp -d /tmp/check_import_res.XXXXXX"))
    if work == "" { print("FAIL temporary directory"); exit("1") }
    let log = work + "/run.log"
    syntaxReject(root, "tests/macos/fixtures/import_missing.k",
        "unresolvable import", log)
    syntaxReject(root, "tests/macos/fixtures/import_missing_colon.k",
        "unresolvable import", log)
    syntaxReject(root, "tests/macos/fixtures/import_missing_nested.k",
        "unresolvable import", log)
    syntaxReject(root, "tests/macos/fixtures/import_empty.k",
        "unresolvable or empty import", log)
    syntaxAccept(root, "tests/macos/fixtures/import_valid.k", log)
    print("OK import resolution checks")
}
