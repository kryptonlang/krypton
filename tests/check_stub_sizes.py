#!/usr/bin/env python3
"""Stub-size audit for compiler/linux_x86/elf.k.

Every runtime stub is emitted as hex-byte text by an emit*Code function and has a
matching *Size() function declaring its byte length. If they ever drift, every
later stub/rodata vaddr is off by the delta (see kr_readfile, 2026-11-12:
declared 135 vs emitted 134), corrupting string literals in generated binaries.
This script fails CI if any mismatch appears.

Usage: python3 tests/check_stub_sizes.py [path-to-elf.k]
Exit 0 = all stubs consistent, 1 = mismatch (prints them).
"""
import re
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else "compiler/linux_x86/elf.k"
SRC = open(PATH).read()

parts = re.split(r"(?m)(?=^func )", SRC)
d = {}
for p in parts:
    m = re.match(r"func (\w+)\(", p)
    if m:
        d[m.group(1)] = p

def bytes_in(body):
    total = 0
    for mm in re.finditer(r"hex(Byte|Dword|Word|Qword|DwordVaddr|QwordVaddr)\(", body):
        total += {"Byte": 1, "Word": 2, "Dword": 4, "Qword": 8,
                  "DwordVaddr": 4, "QwordVaddr": 8}[mm.group(1)]
    # hexPad(n) emits n zero bytes; only allowed with a literal argument count
    for mm in re.finditer(r"hexPad\((\d+)\)", body):
        total += int(mm.group(1))
    return total

def emitted_for(size_name):
    base = size_name[:-4]  # strip "Size"
    cand = [n for n in d if n.lower().startswith("emit" + base.lower())]
    # prefer the exact-case match when several exist (e.g. emitKrAtoiCode vs emitKrAtoi2Code)
    exact = [n for n in cand if n.lower() == ("emit" + base + "Code").lower()
             or n.lower() == ("emit" + base + "CodeFinal").lower()
             or n.lower() == ("emit" + base).lower()]
    if exact:
        cand = exact[:1]
    return cand

mismatches = []
checked = 0
for name, body in d.items():
    if not name.endswith("Size"):
        continue
    # strip // comments before the "if" heuristic so commented prose doesn't skip real stubs
    body_nc = re.sub(r"//[^\n]*", "", body)
    if "if" in body_nc:
        continue  # computed from arguments (e.g. prologueSize(localCount)) — not a fixed stub
    m = re.search(r"emit\s+(\d+)", body)
    if not m:
        continue
    declared = int(m.group(1))
    cand = emitted_for(name)
    if len(cand) != 1:
        continue  # opByteSize/prologueSize are computed tables, not stubs
    actual = bytes_in(d[cand[0]])
    checked += 1
    if actual != declared:
        mismatches.append((name, declared, actual, cand[0]))

for name, declared, actual, emitter in mismatches:
    print(f"MISMATCH {name}: declared {declared} vs emitted {actual} ({emitter})")
print(f"checked {checked} stubs; {len(mismatches)} mismatch(es)")
sys.exit(1 if mismatches else 0)
