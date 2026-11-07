import "k:env"

func q(text) {
    let quote = fromCharCode(39)
    emit quote + replace(text, quote, quote + "\\" + quote + quote) + quote
}
func check(condition, name, work) {
    if !condition {
        print("FAIL " + name)
        print(readFile(work + "/out"))
        print(readFile(work + "/err"))
        exit(1)
    }
    print("OK " + name)
}
func invoke(driver, args, work) {
    emit shellRun(q(driver) + " " + args + " >" + q(work + "/out") + " 2>" + q(work + "/err"))
}
just run {
    let root = envOr("KRYPTON_ROOT", trim(exec("pwd")))
    let driver = root + "/bootstrap/kcc_driver_macos_aarch64"
    let work = trim(exec("mktemp -d /tmp/check_macos_driver.XXXXXX"))
    if work == "" { print("FAIL temporary directory"); exit(1) }
    let library = root + "/tests/macos/fixtures/function_library.k"
    let bad = root + "/tests/macos/fixtures/bare_void.k"
    let good = root + "/tests/macos/test_function_library.k"
    let binary = work + "/program"
    let rc = invoke(driver, "--ir " + q(library), work)
    check(rc == "0" && contains(readFile(work + "/out"), "FUNC libraryValue 0"), "function-only IR remains valid", work)
    rc = invoke(driver, q(library) + " -o " + q(binary), work)
    check(rc == "1" && contains(readFile(work + "/err"), "no entry point") && readFile(work + "/out") == "", "executable entry diagnostic on stderr", work)
    rc = invoke(driver, "--ir " + q(bad), work)
    check(rc == "1" && contains(readFile(work + "/err"), "use '-> do'") && readFile(work + "/out") == "", "frontend failure preserves streams", work)
    writeFile(binary, "preserve previous output")
    rc = invoke(driver, q(bad) + " -o " + q(binary), work)
    check(rc == "1" && readFile(binary) == "preserve previous output", "frontend failure preserves old output", work)
    let unknown = root + "/tests/macos/fixtures/unknown_call.k"
    rc = invoke(driver, q(unknown) + " -o " + q(binary), work)
    check(rc == "1" && readFile(binary) == "preserve previous output", "backend failure preserves old output", work)
    rc = invoke(driver, q(good) + " -o " + q(work + "/missing/program"), work)
    check(rc == "1" && contains(readFile(work + "/err"), "output directory") && readFile(work + "/out") == "", "missing output directory on stderr", work)
    rc = invoke(driver, q(good) + " -o " + q(work), work)
    check(rc == "1" && contains(readFile(work + "/err"), "is a directory"), "directory output rejected", work)
    rc = invoke(driver, q(good) + " -o " + q(binary), work)
    check(rc == "0", "successful build replaces old output", work)
    rc = invoke(binary, "", work)
    check(rc == "0" && contains(readFile(work + "/out"), "[PASS] library works"), "replacement executable works", work)
    rc = invoke(driver, "--ir " + q(good), work)
    check(rc == "0" && startsWith(readFile(work + "/out"), "; Krypton IR"), "IR warnings are not fatal", work)
    rc = invoke(driver, "-r " + q(root + "/tests/macos/fixtures/exit7.k"), work)
    check(rc == "7" && readFile(work + "/out") == "child output\n" && contains(readFile(work + "/err"), "child error"), "run preserves child streams and status", work)
    rc = invoke(driver, "-e " + q("fdWrite(1, \"raw\", 3); exit(9)"), work)
    check(rc == "9" && readFile(work + "/out") == "raw", "eval preserves status and missing newline", work)
    rc = invoke(driver, "-e " + q("emit \"ok\""), work)
    check(rc == "0", "nonnumeric entry result exits zero", work)
    rc = invoke(driver, "-e " + q("exit(\"7\")"), work)
    check(rc == "7", "numeric text exit status", work)
    let argsSource = work + "/args.ks"
    writeFile(argsSource, "just run { if argCount() != 4 || arg(0) != \"two words\" || arg(1) != \"quote 'value'\" || arg(2) != \"\" || arg(3) != \"$(printf wrong);exit 93\" { exit(3) }; print(\"argv preserved\") }")
    rc = invoke(driver, "-r " + q(argsSource) + " " + q("two words") + " " + q("quote 'value'") + " " + q("") + " " + q("$(printf wrong);exit 93"), work)
    check(rc == "0" && readFile(work + "/out") == "argv preserved\n", "run preserves argument boundaries without shell expansion", work)
    let spaced = work + "/space 'quoted'"
    if shellRun("mkdir -p " + q(spaced)) != "0" { print("FAIL spaced directory"); exit(1) }
    let spacedSource = spaced + "/input 'quoted'.ks"
    let spacedBinary = spaced + "/output 'quoted'"
    writeFile(spacedSource, "just run { print(\"quoted path works\") }")
    rc = invoke(driver, q(spacedSource) + " -o " + q(spacedBinary), work)
    check(rc == "0", "source and output paths preserve spaces and quotes", work)
    rc = invoke(spacedBinary, "", work)
    check(rc == "0" && readFile(work + "/out") == "quoted path works\n", "quoted output executable runs", work)
    let modulePath = work + "/bad_module.k"
    writeFile(modulePath, "func broken() { let process = 1; emit process }")
    let source = work + "/import_bad.ks"
    writeFile(source, "import \"" + modulePath + "\"\njust run { broken() }")
    rc = invoke(driver, q(source) + " -o " + q(binary), work)
    check(rc == "1" && contains(readFile(work + "/err"), modulePath + ": error:"), "import errors name their module", work)
    check(trim(exec("find " + q(work) + " -name '.kcc_*' -print")) == "", "staged outputs cleaned", work)
    print("[PASS] macOS compiler driver contracts")
    print("logs: " + work)
}
