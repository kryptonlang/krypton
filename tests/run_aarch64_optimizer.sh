#!/usr/bin/env bash
# Differential raw-vs-optimized smoke test for the native aarch64 pipeline.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FE="$ROOT/compiler/linux_aarch64/kcc-aarch64"
ELF="$ROOT/compiler/linux_aarch64/elf_host"
OPT="$ROOT/compiler/linux_aarch64/optimize_host"
for tool in "$FE" "$ELF" "$OPT"; do
    [[ -x "$tool" ]] || { echo "missing executable: $tool" >&2; exit 2; }
done
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export KRYPTON_ROOT="$ROOT"

for src in tests/test_negative_nums.k tests/test_static.k tests/test_sb_ops.k; do
    name="$(basename "$src" .k)"
    "$FE" --ir "$src" > "$WORK/$name.raw.kir"
    "$OPT" "$WORK/$name.raw.kir" > "$WORK/$name.opt.kir" 2>/dev/null
    "$ELF" "$WORK/$name.raw.kir" "$WORK/$name.raw"
    "$ELF" "$WORK/$name.opt.kir" "$WORK/$name.opt"
    chmod +x "$WORK/$name.raw" "$WORK/$name.opt"
    "$WORK/$name.raw" > "$WORK/$name.raw.out" 2>&1 || true
    "$WORK/$name.opt" > "$WORK/$name.opt.out" 2>&1 || true
    cmp "$WORK/$name.raw.out" "$WORK/$name.opt.out"
    if grep -q '\[FAIL\]' "$WORK/$name.opt.out"; then
        echo "optimized output contains [FAIL]: $src" >&2
        exit 1
    fi
    echo "optimizer differential $name: ok"
done
