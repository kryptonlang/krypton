#!/usr/bin/env kr
// tools/socam_bridge.ks — socam <-> Krypton toolchain boundary for KryptOS
// ISO and artifact assembly.
//
// WHY THIS EXISTS: socam (AGPL-3.0, binary-only in the socam repository) may
// never be linked into, derived from or statically combined with Krypton
// (Apache-2.0) artifacts. This script is the ONLY sanctioned touch-point:
// socam is invoked exclusively as a subprocess across a clean process
// boundary. No FFI, no dynamic loading, no source sharing, no embedding of
// socam assets.
//
// Subprocess discipline (load-bearing): the K-owned runtime on the macho
// driver silently corrupts process state after too many spawned children on
// this host — calls after roughly the fourth exec vanish without a diagnostic.
// Every subcommand therefore folds its shell work into a small number of
// `&&`-chained exec/shellRun invocations (never more than ~5), and validation
// failing mid-chain prints a specific FAIL line before exiting.
//
// Usage (run from the Krypton repository root, macOS arm64 host for artifact;
// iso also usable from the Lima VM for packaging only):
//   kr tools/socam_bridge.ks check              verify socam + driver + smack sources
//   kr tools/socam_bridge.ks cortex             validate the cortex Wayland sources
//                                               (socam explain; Linux hosts also compile
//                                               cortex_wl.k; macOS prints the in-VM build cmd)
//   kr tools/socam_bridge.ks iso [OUT_TAR]      validate, then stage the ISO payload
//                                               tarball (default
//                                               dist/staging/krypton-payload.tar.zst)
//   kr tools/socam_bridge.ks artifact [OUT_BIN] build + ad-hoc sign the SmackUI
//                                               smoke artifact (macOS arm64 only,
//                                               default dist/smack_smoke_macos_arm64)
//
// Environment:
//   SOCAM         absolute path to the socam binary (default: ../socam/bin/socam,
//                 sibling checkout, or `socam` on PATH)
//   KRYPTON_ROOT  Krypton repository root (default: cwd)
//   OUT           staging directory for bridge outputs (default: dist/staging)

import "k:env"


func q(s) {
    let quote = fromCharCode(39)
    emit quote + replace(s, quote, quote + "\\" + quote + quote) + quote
}

func usage() {
    print("usage: socam_bridge.ks check|iso [out.tar.zst]|artifact [out.bin]|cortex")
    exit("1")
}

just run {
    let cmd = ""
    if argCount() > 0 { cmd = arg(0) } else { usage() }
    let root = envOr("KRYPTON_ROOT", trim(exec("pwd")))
    let arch = trim(exec("uname -s -m"))
    let socam = envOr("SOCAM", root + "/../socam/bin/socam")
    let homeSocam = envOr("HOME", "") + "/Documents/GitHub/socam/bin/socam"
    if shellRun("test -x " + q(socam)) != "0" && shellRun("test -x " + q(homeSocam)) == "0" {
        socam = homeSocam
    }
    // The socam payload chain: version + explain on every SmackUI source.
    // Paths under this repository contain no spaces.
    let explainChain = q(socam) + " version >/dev/null 2>&1 && " +
                       q(socam) + " explain " + root + "/stdlib/smack/geometry.k >/dev/null 2>&1 && " +
                       q(socam) + " explain " + root + "/stdlib/smack/view.k >/dev/null 2>&1 && " +
                       q(socam) + " explain " + root + "/stdlib/smack/compositor.k >/dev/null 2>&1 && " +
                       q(socam) + " explain " + root + "/tests/test_smackui_smoke.k >/dev/null 2>&1"
    let driver = root + "/bootstrap/kcc_driver_macos_aarch64"
    if contains(arch, "Linux") { driver = root + "/bootstrap/kcc_driver_linux_x86_64" }

    if cmd == "check" {
        if arch != "Darwin arm64" {
            print("socam_bridge: socam is a macOS arm64 binary; this host reports " + arch)
            exit("1")
        }
        print("socam: " + socam)
        let rc = shellRun(explainChain)
        if rc != "0" {
            print("FAIL socam version/explain chain (rc " + rc + "); run with a present socam: " + socam)
            exit("1")
        }
        print("OK socam explain: geometry.k view.k compositor.k test_smackui_smoke.k")
        let rc2 = shellRun("test -x " + q(driver) + " && KRYPTON_ROOT=" + q(root) + " " + q(driver) + " --version >/dev/null 2>&1")
        if rc2 != "0" {
            print("FAIL driver check failed for " + driver)
            exit("1")
        }
        print("OK driver: " + driver)
        print("check: OK")
        exit("0")
    }

    if cmd == "iso" {
        if arch != "Darwin arm64" && arch != "Linux x86_64" && arch != "Linux aarch64" {
            print("socam_bridge: unsupported host " + arch + " for the iso payload step")
            exit("1")
        }
        let out = envOr("OUT", root + "/dist/staging")
        let target = ""
        if argCount() > 1 { target = arg(1) }
        if target == "" { target = out + "/krypton-payload.tar.zst" }
        // Everything in ONE subprocess chain: validate with socam (macOS hosts
        // only — socam is Mach-O arm64), stage the payload, prune non-Linux
        // binaries, tar --zstd it. The actor for the KryptOS image is the
        // Lima VM + chroot build; this only prepares and validates the tarball.
        let validate = ""
        if arch == "Darwin arm64" { validate = explainChain + " && " }
        let tmp = trim(exec("mktemp -d /tmp/socam-iso.XXXXXX"))
        if tmp == "" { print("FAIL mktemp"); exit("1") }
        let payload = validate +
            "mkdir -p " + q(tmp + "/krypton") + " && " +
            "cp -a " + root + "/bootstrap " + root + "/compiler " + root + "/stdlib " +
                        root + "/headers " + root + "/kr " + root + "/LICENSE " +
                        root + "/examples " + root + "/README.md " + q(tmp + "/krypton/") + " && " +
            "rm -f " + q(tmp + "/krypton/bootstrap/kcc_driver_macos_aarch64") +
                 " " + q(tmp + "/krypton/bootstrap/kcc_driver_windows_x86_64.exe") +
                 " " + q(tmp + "/krypton/bootstrap/kcc_seed_macos_aarch64") +
                 " " + q(tmp + "/krypton/bootstrap/kcc_seed_windows_x86_64.exe") +
                 " " + q(tmp + "/krypton/bootstrap/kcc_seed_linux_aarch64") +
                 " " + q(tmp + "/krypton/bootstrap/macho_host_macos_aarch64") +
                 " " + q(tmp + "/krypton/bootstrap/x64_host_windows_x86_64.exe") +
                 " " + q(tmp + "/krypton/bootstrap/optimize_host_windows_x86_64.exe") +
                 " " + q(tmp + "/krypton/bootstrap/krypton_rt_windows.dll") + " && " +
            "mkdir -p " + q(out) + " && " +
            "tar --zstd -cpf " + q(target) + " -C " + q(tmp) + " krypton && " +
            "rm -rf " + q(tmp)
        let rc = shellRun(payload)
        if rc != "0" {
            print("FAIL payload build (rc " + rc + ")")
            exit("1")
        }
        print("iso payload: " + target)
        print("iso: next step runs the Lima VM build: VM=krypton bash scripts/64-install-krypton.sh")
        exit("0")
    }

    if cmd == "artifact" {
        if arch != "Darwin arm64" {
            print("artifact: macOS arm64 required for the ad-hoc signed smoke artifact (host is " + arch + ")")
            exit("1")
        }
        let outBin = root + "/dist/smack_smoke_macos_arm64"
        if argCount() > 1 { outBin = arg(1) }
        // One subprocess: build -> ad-hoc sign -> run -> verify the marker.
        // Exit code alone cannot prove success: the macho driver can emit a
        // silently truncated binary that still exits 0, so the artifact is
        // only accepted if its output contains the final [PASS] line.
        let logPath = trim(exec("mktemp /tmp/socam-artifact.XXXXXX"))
        if logPath == "" { print("FAIL mktemp"); exit("1") }
        let cmdline = explainChain + " && " +
            "mkdir -p " + q(root + "/dist") + " && " +
            "cd " + q(root) + " && KRYPTON_ROOT=" + q(root) + " " + q(driver) +
            " tests/test_smackui_smoke.k -o " + q(outBin) + " >/dev/null 2>&1 && " +
            "codesign --force --sign - " + q(outBin) + " >/dev/null 2>&1 && " +
            q(outBin) + " >" + q(logPath) + " 2>&1 && " +
            "grep -q '\[PASS\] smackui smoke' " + q(logPath) + "; " +
            "rc=$?; rm -f " + q(logPath) + "; exit $rc"
        let rc = shellRun(cmdline)
        if rc != "0" {
            print("FAIL artifact pipeline (rc " + rc + "): compile/sign/run or [PASS] marker verification failed")
            print("note: the macOS macho driver can emit silently truncated binaries (exit 0, partial output); rebuild or verify with the Linux driver")
            exit("1")
        }
        print("artifact: " + outBin)
        exit("0")
    }

    // cortex: wire the Linux Wayland-native file manager (pure Krypton,
    // no toolkits, no FFI) into the socam gate. On macOS hosts we validate
    // the source with socam and point at the in-VM build; on Linux hosts we
    // actually compile it with the Linux driver and verify the ELF artifact.
    if cmd == "cortex" {
        let cortex = envOr("CORTEX_ROOT", root + "/../cortex")
        let home = envOr("HOME", "")
        let homeCortex = home + "/Documents/GitHub/cortex"
        let homeCortexLn = home + "/Documents/GitHub/cortex-linux"
        if shellRun("test -f " + q(cortex + "/cortex_wl.k")) != "0" && home != "" {
            if shellRun("test -f " + q(homeCortex + "/cortex_wl.k")) == "0" { cortex = homeCortex }
            else if shellRun("test -f " + q(homeCortexLn + "/cortex_wl.k")) == "0" { cortex = homeCortexLn }
        }
        let mainK = cortex + "/cortex_wl.k"
        let srcRc = shellRun("test -f " + q(mainK))
        if srcRc != "0" {
            print("FAIL cortex source not found at " + mainK + " (set CORTEX_ROOT to the cortex checkout)")
            exit("1")
        }
        if arch == "Darwin arm64" {
            print("cortex: " + mainK)
            let rc = shellRun(q(socam) + " explain " + q(mainK) + " >/dev/null 2>&1")
            if rc != "0" {
                print("FAIL socam explain cortex_wl.k (rc " + rc + ")")
                exit("1")
            }
            print("OK socam explain: cortex_wl.k")
        } else {
            print("note: socam explain skipped on " + arch + " (socam is a macOS arm64 binary)")
        }
        if contains(arch, "Linux") {
            let out = envOr("OUT", root + "/dist/staging")
            let bin = out + "/cortex_wl_linux_x86_64"
            let build = "mkdir -p " + q(out) + " && KRYPTON_ROOT=" + q(root) + " " + q(driver) + " " + q(mainK) + " -o " + q(bin) + " && file " + q(bin) +
                        " | grep -q 'x86-64'"
            let brc = shellRun(build)
            if brc != "0" {
                print("FAIL cortex build (rc " + brc + ")")
                exit("1")
            }
            print("OK cortex build: " + bin)
        } else {
            print("note: macOS host — the x86_64 Linux driver cannot run here; build in the VM:")
            print("  limactl shell krypton -- sudo KRYPTON_ROOT=/mnt/lfs/usr/local/krypton /mnt/lfs/usr/local/krypton/bootstrap/kcc_driver_linux_x86_64 " + mainK + " -o /tmp/cortex_wl")
        }
        print("cortex: OK")
        exit("0")
    }

    usage()
}
