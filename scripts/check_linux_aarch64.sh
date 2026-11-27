#!/usr/bin/env bash
# Validate the native Linux AArch64 compiler payload without touching Linux x86
# sources. Safe to run from any host: runtime probes are skipped unless the
# host is Linux/aarch64.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

need_exec() {
    [ -x "$1" ] || { echo "missing executable: $1" >&2; exit 1; }
}

need_exec bootstrap/kcc_seed_linux_aarch64
need_exec compiler/linux_aarch64/kcc-aarch64
need_exec compiler/linux_aarch64/elf_host
need_exec compiler/linux_aarch64/elf_host_x86
need_exec bootstrap/optimize_host_linux_aarch64
need_exec compiler/linux_aarch64/optimize_host

if command -v file >/dev/null 2>&1; then
    file bootstrap/kcc_seed_linux_aarch64 \
         compiler/linux_aarch64/kcc-aarch64 \
         compiler/linux_aarch64/elf_host \
         compiler/linux_aarch64/elf_host_x86 \
         bootstrap/optimize_host_linux_aarch64 \
         compiler/linux_aarch64/optimize_host
fi

case "$(uname -s)/$(uname -m)" in
    Linux/aarch64|Linux/arm64)
        echo "AArch64 host detected; running native compiler probes."
        KRYPTON_ROOT="$ROOT" bootstrap/kcc_seed_linux_aarch64 --version
        KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/kcc-aarch64 --version
        KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/elf_host --version 2>/dev/null || true
        if [ -x bootstrap/kcc_driver_linux_aarch64 ]; then
            KRYPTON_ROOT="$ROOT" bootstrap/kcc_driver_linux_aarch64 --version
            seed_ver="$(KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/kcc-aarch64 --version 2>&1 | sed -E 's/^kcc version //')"
            driver_ver="$(KRYPTON_ROOT="$ROOT" bootstrap/kcc_driver_linux_aarch64 --version 2>&1 | sed -E 's/^kcc version //')"
            [[ "$seed_ver" == "$driver_ver" ]] || { echo "version mismatch: $seed_ver != $driver_ver" >&2; exit 1; }
            tmpdir="$(mktemp -d)"
            trap 'rm -rf "$tmpdir"' EXIT
            printf 'just run { print("aarch64 ok") }\n' > "$tmpdir/hello.k"
            KRYPTON_ROOT="$ROOT" bootstrap/kcc_driver_linux_aarch64 \
                --native "$tmpdir/hello.k" -o "$tmpdir/hello"
            "$tmpdir/hello" | grep -q '^aarch64 ok$'
            KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/kcc-aarch64 --ir "$tmpdir/hello.k" > "$tmpdir/hello.kir"
            KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/optimize_host "$tmpdir/hello.kir" > "$tmpdir/hello_opt.kir"
            KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/elf_host "$tmpdir/hello_opt.kir" "$tmpdir/hello_opt"
            chmod +x "$tmpdir/hello_opt"
            "$tmpdir/hello_opt" | grep -q '^aarch64 ok$'

            KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/kcc-aarch64 --ir tests/test_try_catch.k > "$tmpdir/try.kir"
            compiler/linux_aarch64/elf_host "$tmpdir/try.kir" "$tmpdir/try"
            chmod +x "$tmpdir/try"
            "$tmpdir/try" | grep -q '^try/catch tests done$'

            printf 'just run { print("line=[" + readLine() + "]") }\n' > "$tmpdir/readline.k"
            KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/kcc-aarch64 --ir "$tmpdir/readline.k" > "$tmpdir/readline.kir"
            compiler/linux_aarch64/elf_host "$tmpdir/readline.kir" "$tmpdir/readline"
            chmod +x "$tmpdir/readline"
            printf 'native input\n' | "$tmpdir/readline" | grep -q '^line=\[native input\]$'

            printf 'FUNC __main__ 0\nPUSH "unhandled"\nTHROW\nEND\n' > "$tmpdir/unhandled.kir"
            compiler/linux_aarch64/elf_host "$tmpdir/unhandled.kir" "$tmpdir/unhandled"
            chmod +x "$tmpdir/unhandled"
            set +e
            "$tmpdir/unhandled" >/dev/null 2>&1
            unhandled_rc=$?
            set -e
            [[ "$unhandled_rc" -eq 1 ]] || { echo "unhandled throw exited $unhandled_rc, expected 1" >&2; exit 1; }

            printf 'FUNC __main__ 0\nPUSH 7\nRETURN\nEND\n' > "$tmpdir/status.kir"
            compiler/linux_aarch64/elf_host "$tmpdir/status.kir" "$tmpdir/status"
            chmod +x "$tmpdir/status"
            set +e
            "$tmpdir/status"
            status_rc=$?
            set -e
            [[ "$status_rc" -eq 7 ]] || { echo "main returned $status_rc, expected 7" >&2; exit 1; }

            printf 'FUNC library 0\nPUSH 1\nRETURN\nEND\n' > "$tmpdir/library.kir"
            compiler/linux_aarch64/elf_host "$tmpdir/library.kir" "$tmpdir/library"
            chmod +x "$tmpdir/library"
            "$tmpdir/library"
            echo "native driver, optimizer, exception, input, and exit-status pipelines ok"
        fi
        ;;
    *)
        echo "Artifacts validated; runtime probes skipped on $(uname -s)/$(uname -m)."
        ;;
esac

echo "Linux AArch64 payload is present."
