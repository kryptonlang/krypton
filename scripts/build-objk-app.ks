#!/usr/bin/env kr

func q(value) {
    let quote = fromCharCode(39)
    emit quote + replace(value, quote, quote + "\\" + quote + quote) + quote
}
func fail(message) { printErr("build-objk-app: " + message + "\n"); exit(1) }
func run(command) { if shellRun(command) != "0" { fail("command failed: " + command) } }
func fileExists(path) { emit shellRun("test -f " + q(path)) == "0" }
func pathExists(path) { emit shellRun("test -e " + q(path)) == "0" }
func clean(text) {
    let end = len(text)
    while end > 0 {
        let c = charCode(text[end - 1])
        if c == 10 || c == 13 || c == 32 || c == 9 { end -= 1 } else { break }
    }
    emit substring(text, 0, end)
}
func xml(text) {
    emit replace(replace(replace(replace(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"), fromCharCode(34), "&quot;")
}
func safeName(text) {
    if text == "" || text == "." || text == ".." { emit 0 }
    let i = 0
    while i < len(text) {
        let c = charCode(text[i])
        if !((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 45 || c == 46 || c == 95) { emit 0 }
        i += 1
    }
    emit 1
}
func parentPath(path) {
    let slash = 0 - 1
    let i = 0
    while i < len(path) { if path[i] == "/" { slash = i }; i += 1 }
    if slash == 0 { emit "/" }
    if slash > 0 { emit substring(path, 0, slash) }
    emit "."
}
func installFile(source, target, mode) {
    if !fileExists(source) { fail("missing payload: " + source) }
    run("install -m " + mode + " " + q(source) + " " + q(target))
}

just run {
    if argCount() < 2 { fail("usage: source.k name [--out path.app] [--id identifier] [--version version] [--icon path.icns] [--compiler path]") }
    let source = arg(0)
    let name = arg(1)
    if !safeName(name) { fail("invalid executable name") }
    if !fileExists(source) { fail("source not found: " + source) }
    let cwd = clean(exec("pwd"))
    let root = environ("KRYPTON_ROOT")
    let compiler = "/usr/local/bin/kcc"
    if root != "" { compiler = root + "/bootstrap/kcc_driver_macos_aarch64" }
    let output = cwd + "/dist/" + name + ".app"
    let identifier = "org.krypton-lang.macos." + replace(name, "_", "-")
    let version = ""
    let icon = ""
    let i = 2
    while i < argCount() {
        let option = arg(i)
        if i + 1 >= argCount() { fail("missing value for " + option) }
        let value = arg(i + 1)
        if option == "--out" { output = value }
        else if option == "--id" { identifier = value }
        else if option == "--version" { version = value }
        else if option == "--icon" { icon = value }
        else if option == "--compiler" { compiler = value }
        else { fail("unknown option: " + option) }
        i += 2
    }
    if !startsWith(output, "/") { output = cwd + "/" + output }
    if !endsWith(output, ".app") { fail("output must end in .app") }
    if !safeName(identifier) || contains(identifier, "_") || startsWith(identifier, ".") || endsWith(identifier, ".") || contains(identifier, "..") { fail("invalid bundle identifier") }
    if shellRun(q(compiler) + " --version >/dev/null 2>&1") != "0" { fail("compiler unavailable: " + compiler) }
    let compilerVersion = clean(exec(q(compiler) + " --version 2>&1"))
    if !startsWith(compilerVersion, "kcc version ") { fail("not a Krypton compiler: " + compiler) }
    if version == "" { version = substring(compilerVersion, 12, len(compilerVersion)) }
    if version == "" { fail("missing version") }
    let vi = 0
    while vi < len(version) {
        let c = charCode(version[vi])
        if !((c >= 48 && c <= 57) || c == 46) { fail("version must contain digits and dots") }
        vi += 1
    }
    let versionParts = replace(version, ".", ",")
    if count(versionParts) != 3 || split(versionParts, 0) == "" || split(versionParts, 1) == "" || split(versionParts, 2) == "" { fail("version must be major.minor.patch") }
    if icon == "" && name == "kweb" && root != "" { icon = root + "/kweb/kweb.icns" }
    if icon != "" && !fileExists(icon) { fail("icon not found: " + icon) }
    let parent = parentPath(output)
    run("mkdir -p " + q(parent))
    let stage = clean(exec("mktemp -d " + q(parent + "/.objk-build.XXXXXX")))
    if stage == "" { fail("cannot create staging folder") }
    let app = stage + "/new.app"
    let mac = app + "/Contents/MacOS"
    let resources = app + "/Contents/Resources"
    run("mkdir -p " + q(mac) + " " + q(resources))
    run(q(compiler) + " " + q(source) + " -o " + q(mac + "/" + name))
    let iconXML = ""
    if icon != "" {
        installFile(icon, resources + "/app.icns", "0644")
        iconXML = "<key>CFBundleIconFile</key><string>app</string>\n"
    }
    if name == "kweb" {
        if root == "" { fail("kweb requires KRYPTON_ROOT for its bundled toolchain") }
        let cli = root + "/kweb/kweb"
        if !fileExists(cli) { cli = root + "/web/kweb" }
        installFile(cli, mac + "/kweb-cli", "0755")
        let payload = resources + "/krypton"
        run("mkdir -p " + q(payload + "/bootstrap") + " " + q(payload + "/compiler/macos_arm64"))
        installFile(root + "/bootstrap/kcc_driver_macos_aarch64", payload + "/bootstrap/kcc_driver_macos_aarch64", "0755")
        installFile(root + "/bootstrap/kcc_seed_macos_aarch64", payload + "/bootstrap/kcc_seed_macos_aarch64", "0755")
        installFile(root + "/compiler/macos_arm64/kcc-arm64", payload + "/compiler/macos_arm64/kcc-arm64", "0755")
        installFile(root + "/compiler/macos_arm64/macho_host", payload + "/compiler/macos_arm64/macho_host", "0755")
        installFile(root + "/compiler/compile.k", payload + "/compiler/compile.k", "0644")
        installFile(root + "/compiler/macos_arm64/macho_arm64_self.k", payload + "/compiler/macos_arm64/macho_arm64_self.k", "0644")
        run("env COPYFILE_DISABLE=1 ditto --norsrc " + q(root + "/stdlib") + " " + q(payload + "/stdlib"))
        run("env COPYFILE_DISABLE=1 ditto --norsrc " + q(root + "/headers") + " " + q(payload + "/headers"))
        run("touch " + q(payload + "/compiler/macos_arm64/macho_host"))
    }
    let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<plist version=\"1.0\"><dict>\n" +
        "<key>CFBundlePackageType</key><string>APPL</string>\n" +
        "<key>CFBundleName</key><string>" + xml(name) + "</string>\n" +
        "<key>CFBundleDisplayName</key><string>" + xml(name) + "</string>\n" +
        "<key>CFBundleExecutable</key><string>" + xml(name) + "</string>\n" +
        "<key>CFBundleIdentifier</key><string>" + xml(identifier) + "</string>\n" +
        "<key>CFBundleShortVersionString</key><string>" + xml(version) + "</string>\n" +
        "<key>CFBundleVersion</key><string>" + xml(version) + "</string>\n" + iconXML +
        "<key>LSMinimumSystemVersion</key><string>14.0</string>\n" +
        "<key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>\n" +
        "<key>NSHighResolutionCapable</key><true/>\n" +
        "<key>NSDocumentsFolderUsageDescription</key><string>Open and build project files.</string>\n" +
        "</dict></plist>\n"
    writeFile(app + "/Contents/Info.plist", plist)
    run("plutil -lint " + q(app + "/Contents/Info.plist"))
    run("codesign --force --sign - " + q(app))
    run("codesign --verify --deep --strict " + q(app))
    let previous = stage + "/previous.app"
    if pathExists(output) { run("mv " + q(output) + " " + q(previous)) }
    if shellRun("mv " + q(app) + " " + q(output)) != "0" {
        if pathExists(previous) { run("mv " + q(previous) + " " + q(output)) }
        fail("cannot install completed bundle")
    }
    run("rm -rf " + q(stage))
    print("built " + output)
}
