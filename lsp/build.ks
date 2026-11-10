#!/usr/bin/env kr
// kr lsp/build.ks — build kls.exe from lsp/kls.k.
//
// CURRENTLY USES C+gcc — this is the deprecated path. Migrate to
// `kcc.exe -o kls.exe lsp/kls.k` (native pipeline) as soon as kls.k
// builds cleanly that way. Same goal as kcc.sh's --gcc deprecation:
// no C compiler in the user-invocation path, ever.
import "k:fs"

just run {
    let root = fsCwd()

    print("[1/2] kcc.exe lsp/kls.k -> lsp/_kls.c")
    let rcKcc = shellRun("kcc.exe lsp\\kls.k > lsp\\_kls.c")
    if rcKcc != "0" {
        print("kcc failed (rc=" + rcKcc + ")")
        exit("1")
    }

    // DEPRECATED step — when kls.k builds via native, drop steps 1+2
    // and replace with a single `kcc.exe -o kls.exe lsp/kls.k`.
    print("[2/2] gcc lsp/_kls.c -> kls.exe")
    let rcGcc = shellRun("gcc lsp\\_kls.c -o kls.exe -w")
    if rcGcc != "0" {
        print("gcc failed (rc=" + rcGcc + ")")
        exit("1")
    }

    print("")
    print("built kls.exe")
    if fsFileExists("kls.exe") == "1" {
        print("kls.exe present in " + root)
    } else {
        print("WARN: kls.exe not found after build")
    }
}
