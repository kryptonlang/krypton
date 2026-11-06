import "k:env"

func q(text) {
    let quote = fromCharCode(39)
    emit quote + replace(text, quote, quote + "\\" + quote + quote) + quote
}

just run {
    if trim(exec("uname -s")) != "Darwin" { print("SKIP macOS native suite"); exit(0) }
    let root = envOr("KRYPTON_ROOT", trim(exec("pwd")))
    let driver = root + "/bootstrap/kcc_driver_macos_aarch64"
    let work = trim(exec("mktemp -d /tmp/check_macos_native.XXXXXX"))
    if work == "" { print("FAIL temporary directory"); exit(1) }
    let files = exec("find " + q(root + "/tests") + " -maxdepth 1 -name 'test_*.k' -print | LC_ALL=C sort")
    let skips = ",test_bytes,test_bytes_win,test_conpty_win,test_dll_exports,test_fs_extended,test_process_win,test_process_win_argv,test_settings,"
    let passed = 0
    let failed = 0
    let skipped = 0
    let i = 0
    while i < lineCount(files) {
        let source = trim(getLine(files, i))
        if source != "" {
            let name = replace(replace(source, root + "/tests/", ""), ".k", "")
            if contains(skips, "," + name + ",") {
                print("SKIP " + name + " (Windows-only or raw pointer-width contract)")
                skipped = skipped + 1
            } else {
                let binary = work + "/" + name
                let log = work + "/" + name + ".log"
                let cmd = "KRYPTON_ROOT=" + q(root) + " " + q(driver) + " " + q(source) + " -o " + q(binary)
                let rc = shellRun(cmd + " >" + q(log) + " 2>&1")
                if rc == "0" {
                    let args = ""
                    if name == "test_file_read" { args = " " + q(source) }
                    rc = shellRun("cd " + q(work) + " && printf 'release test\\n' | " + q(binary) + args + " >" + q(log) + " 2>&1")
                }
                let output = readFile(log)
                if rc != "0" || contains(output, "[FAIL]") || startsWith(output, "FAIL ") || contains(output, "\nFAIL ") || contains(output, "[SKIP]") {
                    print("FAIL " + name + " rc=" + rc)
                    print(output)
                    failed = failed + 1
                } else {
                    print("PASS " + name)
                    passed = passed + 1
                }
            }
        }
        i = i + 1
    }
    print("native: " + passed + " passed / " + failed + " failed / " + skipped + " skipped")
    print("logs: " + work)
    if failed != 0 { exit(1) }
}
