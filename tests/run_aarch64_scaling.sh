#!/usr/bin/env bash
# Large-IR regression for the Linux aarch64 backend's StringBuilder code path.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="${1:-$ROOT/compiler/linux_aarch64/elf_host}"
[[ -x "$BACKEND" ]] || { echo "missing backend: $BACKEND" >&2; exit 2; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for N in 5000 40000; do
    awk -v n="$N" 'BEGIN {
        print "; Krypton IR"
        print "FUNC __main__ 0"
        for (i = 0; i < n; i++) { print "PUSH 1"; print "POP" }
        print "PUSH \"large ok\""
        print "BUILTIN kp 1"
        print "POP"
        print "END"
    }' > "$WORK/large_$N.kir"
    "$BACKEND" "$WORK/large_$N.kir" "$WORK/large_$N"
    chmod +x "$WORK/large_$N"
    "$WORK/large_$N" | grep -q '^large ok$'
    echo "large IR $N operations: ok"
done
