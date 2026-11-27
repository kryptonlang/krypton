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

file bootstrap/kcc_seed_linux_aarch64 \
     compiler/linux_aarch64/kcc-aarch64 \
     compiler/linux_aarch64/elf_host \
     compiler/linux_aarch64/elf_host_x86

case "$(uname -s)/$(uname -m)" in
    Linux/aarch64|Linux/arm64)
        echo "AArch64 host detected; running native compiler probes."
        KRYPTON_ROOT="$ROOT" bootstrap/kcc_seed_linux_aarch64 --version
        KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/kcc-aarch64 --version
        KRYPTON_ROOT="$ROOT" compiler/linux_aarch64/elf_host --version 2>/dev/null || true
        if [ -x bootstrap/kcc_driver_linux_aarch64 ]; then
            KRYPTON_ROOT="$ROOT" bootstrap/kcc_driver_linux_aarch64 --version
            tmpdir="$(mktemp -d)"
            trap 'rm -rf "$tmpdir"' EXIT
            printf 'just run { print("aarch64 ok") }\n' > "$tmpdir/hello.k"
            KRYPTON_ROOT="$ROOT" bootstrap/kcc_driver_linux_aarch64 \
                --native "$tmpdir/hello.k" -o "$tmpdir/hello"
            "$tmpdir/hello" | grep -q '^aarch64 ok$'
            echo "native driver pipeline ok"
        fi
        ;;
    *)
        echo "Artifacts validated; runtime probes skipped on $(uname -s)/$(uname -m)."
        ;;
esac

echo "Linux AArch64 payload is present."
