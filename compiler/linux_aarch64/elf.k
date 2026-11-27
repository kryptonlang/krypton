// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// compiler/linux_aarch64/elf.k — native aarch64 Linux ELF backend.
//
// Cross backend: built by the x86 kcc, runs on x86, emits aarch64. Reads Krypton
// IR (arg 0), writes a static syscall-only aarch64 ELF (arg 1). Test under qemu.
//
// Status: native self-hosted aarch64 ELF backend with integers, boxed f64,
// strings, locals/globals, functions/closures, structs, arrays/slices, buffers,
// exceptions, line input, Linux syscalls, sockets, PTYs, and static ELF output.
// The main code, helper, and data accumulators use doubling StringBuilders; keep
// assigning the returned handle because growth may relocate it. Runtime helpers
// occupy fixed padded slots so offsets remain stable across self-host generations.
//
// aarch64 words exceed the int ceiling (0x7F000000), so each is emitted byte-wise
// via two 16-bit halves (wordHL). Operand stack = register x20 (grows down);
// locals base = x19; helpers called via BL (return in x30, leaf, don't touch x19/x20).

func hexByte(n) {
    let HEX = "0123456789ABCDEF"
    let v = n
    if v < 0 { v = v + 256 }
    if v > 255 { v = v % 256 }
    emit "x" + HEX[v / 16] + HEX[v % 16]
}
// one 32-bit instruction as high16:low16 (each < 65536), little-endian.
func wordHL(hi16, lo16) {
    emit hexByte(lo16 % 256) + hexByte(lo16 / 256) + hexByte(hi16 % 256) + hexByte(hi16 / 256)
}

// ── instruction encoders (validated against qemu) ────────────────────────────
func e_movz(rd, imm)   { let p = imm * 32 + rd  emit wordHL(53888 + p / 65536, p % 65536) } // movz Xd,#imm
func e_movk16(rd, imm) { let p = imm * 32 + rd  emit wordHL(62112 + p / 65536, p % 65536) } // movk Xd,#imm,lsl16
func e_movk32(rd, imm) { let p = imm * 32 + rd  emit wordHL(62144 + p / 65536, p % 65536) } // movk Xd,#imm,lsl32
func e_movk48(rd, imm) { let p = imm * 32 + rd  emit wordHL(62176 + p / 65536, p % 65536) } // movk Xd,#imm,lsl48
func e_movzHi(rd, imm) { let p = imm * 32 + rd  emit wordHL(53920 + p / 65536, p % 65536) } // movz Xd,#imm,lsl16
func e_movz32(rd, imm) { let p = imm * 32 + rd  emit wordHL(53952 + p / 65536, p % 65536) } // movz Xd,#imm,lsl32
func e_movz48(rd, imm) { let p = imm * 32 + rd  emit wordHL(53984 + p / 65536, p % 65536) } // movz Xd,#imm,lsl48
func e_addi(rd, rn, imm) { let p = imm * 1024 + rn * 32 + rd  emit wordHL(37120 + p / 65536, p % 65536) }
func e_subi(rd, rn, imm) { let p = imm * 1024 + rn * 32 + rd  emit wordHL(53504 + p / 65536, p % 65536) }
func e_str0(rt, rn)  { let p = rn * 32 + rt  emit wordHL(63744, p) }                 // str Xt,[Xn]
func e_ldr0(rt, rn)  { let p = rn * 32 + rt  emit wordHL(63808, p) }                 // ldr Xt,[Xn]
func e_strIdx(rt, rn, slot) { let p = slot * 2048 + rn * 32 + rt  emit wordHL(63744 + p / 65536, p % 65536) }
func e_ldrIdx(rt, rn, slot) { let p = slot * 2048 + rn * 32 + rt  emit wordHL(63808 + p / 65536, p % 65536) }
func e_addr(rd, rn, rm) { emit wordHL(35584 + rm, rn * 32 + rd) }                    // add Xd,Xn,Xm
func e_subr(rd, rn, rm) { emit wordHL(51968 + rm, rn * 32 + rd) }                    // sub Xd,Xn,Xm
func e_mul(rd, rn, rm)  { let p = 31744 + rn * 32 + rd  emit wordHL(39680 + rm + p / 65536, p % 65536) }
func e_udiv(rd, rn, rm) { let p = 2048 + rn * 32 + rd   emit wordHL(39616 + rm + p / 65536, p % 65536) }
func e_sdiv(rd, rn, rm) { let p = 3072 + rn * 32 + rd   emit wordHL(39616 + rm + p / 65536, p % 65536) } // sdiv Xd,Xn,Xm (signed)
func e_msub(rd, rn, rm, ra) { let p = 32768 + ra * 1024 + rn * 32 + rd  emit wordHL(39680 + rm + p / 65536, p % 65536) }
func e_cmp(rn, rm)   { let p = rn * 32 + 31  emit wordHL(60160 + rm + p / 65536, p % 65536) } // subs xzr,Xn,Xm
func e_cmpi0(rn) { let p = rn * 32 + 31  emit wordHL(61696 + p / 65536, p % 65536) }          // cmp Xn,#0
func e_cset(rd, cc) { let p = 2016 + cc * 4096 + rd  emit wordHL(39583 + p / 65536, p % 65536) } // cset Xd (csinc cond=cc)
func e_and(rd, rn, rm) { emit wordHL(35328 + rm, rn * 32 + rd) }                     // and Xd,Xn,Xm (0x8A00)
func e_orr(rd, rn, rm) { emit wordHL(43520 + rm, rn * 32 + rd) }                     // orr Xd,Xn,Xm (0xAA00)
func e_eor(rd, rn, rm) { emit wordHL(51712 + rm, rn * 32 + rd) }                     // eor Xd,Xn,Xm (0xCA00)
func e_orn(rd, rn, rm) { emit wordHL(43552 + rm, rn * 32 + rd) }                     // orn Xd,Xn,Xm (0xAA20); mvn = orn Xd,xzr,Xm
func e_lslv(rd, rn, rm) { let p = 8192 + rn * 32 + rd  emit wordHL(39616 + rm + p / 65536, p % 65536) } // lslv Xd,Xn,Xm
func e_lsrv(rd, rn, rm) { let p = 9216 + rn * 32 + rd  emit wordHL(39616 + rm + p / 65536, p % 65536) } // lsrv Xd,Xn,Xm
func e_csel(rd, rn, rm, cond) { let p = cond * 4096 + rn * 32 + rd  emit wordHL(39552 + rm + p / 65536, p % 65536) } // csel Xd,Xn,Xm,cond
func e_movr(rd, rm)  { let p = 992 + rd  emit wordHL(43520 + rm + p / 65536, p % 65536) }     // mov Xd,Xm
func e_strb(wt, xn)  { let p = xn * 32 + wt  emit wordHL(14592, p) }                 // strb Wt,[Xn]
func e_ldrbO(wt, xn, xm) { let p = 26624 + xn * 32 + wt  emit wordHL(14432 + xm + p / 65536, p % 65536) }
func e_ldrhO(wt, xn, xm) { let p = 26624 + xn * 32 + wt  emit wordHL(30816 + xm + p / 65536, p % 65536) }  // ldrh Wt,[Xn,Xm] (u16 LE, zero-ext)
func e_ldrwO(wt, xn, xm) { let p = 26624 + xn * 32 + wt  emit wordHL(47200 + xm + p / 65536, p % 65536) }  // ldr  Wt,[Xn,Xm] (u32 LE, zero-ext)
func e_ldrb0(wt, xn) { let p = xn * 32 + wt  emit wordHL(14656, p) }                 // ldrb Wt,[Xn]
func e_strbO(wt, xn, off) { let p = off * 1024 + xn * 32 + wt  emit wordHL(14592 + p / 65536, p % 65536) } // strb Wt,[Xn,#off]
func e_strbR(wt, xn, xm) { let p = 26624 + xn * 32 + wt  emit wordHL(14368 + xm + p / 65536, p % 65536) } // strb Wt,[Xn,Xm]
func e_strw0(wt, xn)  { let p = xn * 32 + wt  emit wordHL(47360, p) }                 // str Wt,[Xn]
func e_strhO(wt, xn, off) { let p = (off / 2) * 1024 + xn * 32 + wt  emit wordHL(30976 + p / 65536, p % 65536) } // strh Wt,[Xn,#off bytes]
func e_strwO(wt, xn, off) { let p = (off / 4) * 1024 + xn * 32 + wt  emit wordHL(47360 + p / 65536, p % 65536) } // str Wt,[Xn,#off bytes]
func e_strhR(wt, xn, xm) { let p = 26624 + xn * 32 + wt  emit wordHL(30752 + xm + p / 65536, p % 65536) } // strh Wt,[Xn,Xm] (u16)
func e_str8(rt, rn, off8) { let p = off8 * 1024 + rn * 32 + rt  emit wordHL(63744 + p / 65536, p % 65536) } // str Xt,[Xn,#off8*8]
func e_ldr8(rt, rn, off8) { let p = off8 * 1024 + rn * 32 + rt  emit wordHL(63808 + p / 65536, p % 65536) } // ldr Xt,[Xn,#off8*8]
func e_ret() { emit wordHL(54879, 960) }
func e_svc() { emit wordHL(54272, 1) }
func e_rev16(rd, rn) { let p = rn * 32 + rd  emit wordHL(23232, 1024 + p) }
func e_rev32(rd, rn) { let p = rn * 32 + rd  emit wordHL(23232, 2048 + p) }
func e_rev64(rd, rn) { let p = rn * 32 + rd  emit wordHL(56000, 3072 + p) }
func e_yield() { emit wordHL(54531, 8255) }
func e_dmbIsh() { emit wordHL(54531, 15295) }
func e_dsbIsh() { emit wordHL(54531, 15263) }
func e_dmbIshld() { emit wordHL(54531, 14783) }
func e_dmbIshst() { emit wordHL(54531, 15039) }
// branches: off = target - this instruction, in bytes (multiple of 4)
func e_b(dsp)  { let q = dsp / 4  if q < 0 { q = q + 67108864 }  emit wordHL(5120 + q / 65536, q % 65536) }
func e_bl(dsp) { let q = dsp / 4  if q < 0 { q = q + 67108864 }  emit wordHL(37888 + q / 65536, q % 65536) }
func e_blr(rm) { emit wordHL(54847, rm * 32) }                 // blr Xm
func e_br(rm)  { emit wordHL(54815, rm * 32) }                 // br Xm
func e_cbz(rt, dsp)  { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + rt  emit wordHL(46080 + p / 65536, p % 65536) }
func e_cbnz(rt, dsp) { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + rt  emit wordHL(46336 + p / 65536, p % 65536) }
func e_bhs(dsp) { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + 2  emit wordHL(21504 + p / 65536, p % 65536) }
func e_bge(dsp) { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + 10 emit wordHL(21504 + p / 65536, p % 65536) } // b.ge (signed >=, cond GE=10)
func e_blt(dsp) { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + 11 emit wordHL(21504 + p / 65536, p % 65536) } // b.lt (signed <, cond LT=11)
func e_ble(dsp) { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + 13 emit wordHL(21504 + p / 65536, p % 65536) } // b.le (signed <=, cond LE=13)
func e_bne(dsp) { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + 1  emit wordHL(21504 + p / 65536, p % 65536) } // b.ne (cond NE=1)
func e_bgt(dsp) { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + 12 emit wordHL(21504 + p / 65536, p % 65536) } // b.gt (signed >, cond GT=12)
func e_movn(rd, imm) { let p = imm * 32 + rd  emit wordHL(37504 + p / 65536, p % 65536) } // movn Xd,#imm (NOT imm); movn Xd,#0 = -1
func e_beq(dsp) { let q = dsp / 4  if q < 0 { q = q + 524288 }  let p = q * 32 + 0  emit wordHL(21504 + p / 65536, p % 65536) } // b.eq (cond EQ=0)
func e_nop() { emit wordHL(54531, 8223) }
func e_scvtf(dd, xn) { emit wordHL(40546, xn * 32 + dd) }
func e_fcvtzs(xd, dn) { emit wordHL(40568, dn * 32 + xd) }
func e_fadd(dd, dn, dm) { emit wordHL(7776 + dm, 10240 + dn * 32 + dd) }
func e_fsub(dd, dn, dm) { emit wordHL(7776 + dm, 14336 + dn * 32 + dd) }
func e_fmul(dd, dn, dm) { emit wordHL(7776 + dm, 2048 + dn * 32 + dd) }
func e_fdiv(dd, dn, dm) { emit wordHL(7776 + dm, 6144 + dn * 32 + dd) }
func e_fneg(dd, dn) { emit wordHL(7777, 16384 + dn * 32 + dd) }
func e_fabs(dd, dn) { emit wordHL(7776, 49152 + dn * 32 + dd) }
func e_frintm(dd, dn) { emit wordHL(7781, 16384 + dn * 32 + dd) }
func e_frintp(dd, dn) { emit wordHL(7780, 49152 + dn * 32 + dd) }
func e_frintn(dd, dn) { emit wordHL(7780, 16384 + dn * 32 + dd) }
func e_fsqrt(dd, dn) { emit wordHL(7777, 49152 + dn * 32 + dd) }
func e_fcmp(dn, dm) { emit wordHL(7776 + dm, 8192 + dn * 32) }
func e_fcmp0(dn) { emit wordHL(7776, 8200 + dn * 32) }
func e_ldrd(dt, xn) { emit wordHL(64832, xn * 32 + dt) }
func e_strd(dt, xn) { emit wordHL(64768, xn * 32 + dt) }

// composites
func c_push() { emit e_subi(20, 20, 16) + e_str0(0, 20) }      // push x0
func c_pop0() { emit e_ldr0(0, 20) + e_addi(20, 20, 16) }      // pop -> x0
func c_pop1() { emit e_ldr0(1, 20) + e_addi(20, 20, 16) }      // pop -> x1
func c_loadImm(v) {                                            // x0 = signed 32-bit
    let lo = v % 65536
    if lo < 0 { lo = lo + 65536 }
    let hi = ((v - lo) / 65536) % 65536
    if hi < 0 { hi = hi + 65536 }
    if v < 0 {
        let c = e_movz(0, lo) + e_movk16(0, hi) + e_movk32(0, 65535)
        emit c + e_movk48(0, 65535)
    }
    emit e_movz(0, lo) + e_movk16(0, hi)
}
func parseImm(s) {
    let i = 0
    let neg = 0
    if len(s) > 0 && s[0] == "-" { neg = 1  i = 1 }
    let v = 0
    while i < len(s) {
        v = v * 10 + (charCode(s[i]) - 48)
        i = i + 1
    }
    if neg == 1 { v = 0 - v }
    emit v
}
func immBytes(s) {
    if len(s) > 0 && s[0] == "-" { emit "24" }
    emit "16"
}
func c_loadHalves(rd, lo16, hi16) {                             // xd = hi16:lo16 (32-bit)
    emit e_movz(rd, lo16) + e_movk16(rd, hi16)
}
func c_load64(rd, v) {
    emit e_movz(rd, v % 65536) + e_movk16(rd, (v / 65536) % 65536) + e_movk32(rd, 0) + e_movk48(rd, 0)
}
// Fixed-size runtime helper slots keep offsets stable across self-host
// generations even when a source-level append is optimized or reordered.
func padTo(code, bytes) {
    let b = sbNew()
    b = sbAppend(b, code)
    let have = len(code) / 12
    let want = bytes / 4
    if have > want { printErr("aarch64 helper exceeds slot\n")  exit(1) }
    while have < want {
        b = sbAppend(b, e_nop())
        have = have + 1
    }
    emit sbToString(b)
}

// ── runtime helpers (ported from the validated prototype) ────────────────────
// Heap = BSS above the file; x22 = bump pointer (set in the prologue).
// kr_alloc: x0=size -> x0=ptr, bumps x22. Leaf (uses x15).
func emitAlloc() {
    emit e_movr(15, 22) + e_addr(22, 22, 0) + e_movr(0, 15) + e_ret()
}
// kr_str_int: x0=value(>=0) -> x0 = ptr to NUL-term decimal in a FRESH heap buffer
// (heap-allocated so two conversions can coexist during concat). Saves lr in x24;
// allocOff/thisOff are byte offsets, BL disp = allocOff-(thisOff+12).
// Signed: handles negative val by emitting '-' then the magnitude. 128 bytes.
// x6 = neg flag. Layout offsets in [brackets].
func emitStrInt(allocOff, thisOff) {
    let c = e_movr(24, 30) + e_movr(10, 0) + e_movz(0, 24)            // [0]  x24=lr; x10=val; x0=24 (size)
    c = c + e_bl(allocOff - (thisOff + 12))                          // [12] bl kr_alloc -> x0=buf
    c = c + e_addi(1, 0, 23) + e_movr(0, 10) + e_movz(4, 10) + e_strb(31, 1)  // [16] x1=buf+23; x0=val; x4=10; *x1=NUL
    c = c + e_movz(6, 0) + e_cmpi0(0) + e_bge(12) + e_subr(0, 31, 0) + e_movz(6, 1)  // [32] x6=0; if val<0: neg x0, x6=1
    c = c + e_cbz(0, 36)                                             // [52] x0==0 -> .zero (88)
    c = c + e_udiv(3, 0, 4) + e_msub(5, 3, 4, 0) + e_addi(5, 5, 48) + e_subi(1, 1, 1)  // [56] .loop
    c = c + e_strb(5, 1) + e_movr(0, 3) + e_cbnz(0, 0 - 24)          // [72] *x1=dig; x0=q; x0!=0 -> .loop (56)
    c = c + e_b(16)                                                  // [84] -> .signcheck (100)
    c = c + e_subi(1, 1, 1) + e_movz(2, 48) + e_strb(2, 1)           // [88] .zero: x1--; *x1='0'
    c = c + e_cbz(6, 16)                                             // [100] .signcheck: x6==0 -> .done (116)
    c = c + e_subi(1, 1, 1) + e_movz(2, 45) + e_strb(2, 1)           // [104] x1--; *x1='-'
    c = c + e_movr(0, 1) + e_movr(30, 24) + e_ret()                  // [116] .done: x0=x1; restore lr; ret
    emit c
}
// kr_hex: x0=int -> x0=lowercase hex string (sign+magnitude). 144 bytes. 24B buf.
func emitHex(allocOff, thisOff) {
    let c = e_movr(24, 30) + e_movr(10, 0) + e_movz(0, 24)            // [0]  x24=lr; x10=val; x0=24
    c = c + e_bl(allocOff - (thisOff + 12))                          // [12] bl kr_alloc -> x0=buf
    c = c + e_addi(1, 0, 23) + e_movr(0, 10) + e_movz(4, 16) + e_strb(31, 1)  // [16] x1=buf+23; x0=val; x4=16; *x1=0
    c = c + e_movz(6, 0) + e_cmpi0(0) + e_bge(12) + e_subr(0, 31, 0) + e_movz(6, 1)  // [32] sign
    c = c + e_cbz(0, 52)                                             // [52] x0==0 -> .zero (104)
    c = c + e_udiv(3, 0, 4) + e_msub(5, 3, 4, 0) + e_addi(5, 5, 48)  // [56] .loop: x3=x0/16; x5=rem; +'0'
    c = c + e_subi(7, 5, 58) + e_cmpi0(7) + e_blt(8) + e_addi(5, 5, 39)  // [68] if x5>'9'(x7>=0): x5 += 0x27 (a-f)
    c = c + e_subi(1, 1, 1) + e_strb(5, 1) + e_movr(0, 3) + e_cbnz(0, 0 - 40)  // [84] .store; x0=q; !=0 -> .loop (56)
    c = c + e_b(16)                                                  // [100] -> .signcheck (116)
    c = c + e_subi(1, 1, 1) + e_movz(2, 48) + e_strb(2, 1)           // [104] .zero: *x1='0'
    c = c + e_cbz(6, 16)                                             // [116] .signcheck: x6==0 -> .done (132)
    c = c + e_subi(1, 1, 1) + e_movz(2, 45) + e_strb(2, 1)           // [120] *x1='-'
    c = c + e_movr(0, 1) + e_movr(30, 24) + e_ret()                  // [132] .done
    emit c
}
// kr_bin: x0=int -> x0=binary string (sign+magnitude). 128 bytes. 72B buf (64 bits + sign + nul).
func emitBin(allocOff, thisOff) {
    let c = e_movr(24, 30) + e_movr(10, 0) + e_movz(0, 72)            // [0]  x24=lr; x10=val; x0=72
    c = c + e_bl(allocOff - (thisOff + 12))                          // [12] bl kr_alloc -> x0=buf
    c = c + e_addi(1, 0, 71) + e_movr(0, 10) + e_movz(4, 2) + e_strb(31, 1)  // [16] x1=buf+71; x0=val; x4=2; *x1=0
    c = c + e_movz(6, 0) + e_cmpi0(0) + e_bge(12) + e_subr(0, 31, 0) + e_movz(6, 1)  // [32] sign
    c = c + e_cbz(0, 36)                                             // [52] x0==0 -> .zero (88)
    c = c + e_udiv(3, 0, 4) + e_msub(5, 3, 4, 0) + e_addi(5, 5, 48) + e_subi(1, 1, 1)  // [56] .loop
    c = c + e_strb(5, 1) + e_movr(0, 3) + e_cbnz(0, 0 - 24)          // [72] *x1=dig; x0=q; !=0 -> .loop (56)
    c = c + e_b(16)                                                  // [84] -> .signcheck (100)
    c = c + e_subi(1, 1, 1) + e_movz(2, 48) + e_strb(2, 1)           // [88] .zero: *x1='0'
    c = c + e_cbz(6, 16)                                             // [100] .signcheck: x6==0 -> .done (116)
    c = c + e_subi(1, 1, 1) + e_movz(2, 45) + e_strb(2, 1)           // [104] *x1='-'
    c = c + e_movr(0, 1) + e_movr(30, 24) + e_ret()                  // [116] .done
    emit c
}
// kr_padleft(x0=s, x1=width int, x2=pad ptr) -> padded string. 136 bytes.
// width<=len(s) returns s. Else alloc(width+1), fill (width-len) pad chars, copy s.
// x10=s x11=width x12=padchar x13=slen x14=buf x26=lr.
func emitPadLeft(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 0) + e_movr(11, 1) + e_ldrb0(12, 2)  // [0] save lr,s,width; x12=pad[0]
    c = c + e_movz(13, 0)                                            // [16] slen=0
    c = c + e_ldrbO(3, 10, 13) + e_cbz(3, 12) + e_addi(13, 13, 1) + e_b(0 - 12)  // [20] .sl: strlen(s)->x13
    c = c + e_cmp(11, 13) + e_ble(84)                               // [36] width<=slen -> .rets (124)
    c = c + e_addi(0, 11, 1) + e_bl(allocOff - (thisOff + 48))      // [44] x0=alloc(width+1)
    c = c + e_movr(14, 0) + e_movr(1, 0) + e_subr(2, 11, 13)        // [52] x14=buf; x1=cursor; x2=width-slen
    c = c + e_cbz(2, 20) + e_strb(12, 1) + e_addi(1, 1, 1) + e_subi(2, 2, 1) + e_b(0 - 16)  // [64] .fill: pad
    c = c + e_movz(3, 0)                                            // [84] .copy: i=0
    c = c + e_ldrbO(4, 10, 3) + e_strb(4, 1) + e_addi(1, 1, 1) + e_cbz(4, 12) + e_addi(3, 3, 1) + e_b(0 - 20)  // [88] .cl: copy s incl nul
    c = c + e_movr(0, 14) + e_movr(30, 26) + e_ret()               // [112] .cdone: return buf
    c = c + e_movr(0, 10) + e_movr(30, 26) + e_ret()               // [124] .rets: return s
    emit c
}
// kr_padright(x0=s, x1=width int, x2=pad ptr) -> padded string. 140 bytes.
// Copies s (no nul), then fills (width-len) pad chars, then writes the NUL.
func emitPadRight(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 0) + e_movr(11, 1) + e_ldrb0(12, 2)  // [0] save lr,s,width; x12=pad[0]
    c = c + e_movz(13, 0)                                            // [16] slen=0
    c = c + e_ldrbO(3, 10, 13) + e_cbz(3, 12) + e_addi(13, 13, 1) + e_b(0 - 12)  // [20] .sl: strlen(s)->x13
    c = c + e_cmp(11, 13) + e_ble(88)                               // [36] width<=slen -> .rets (128)
    c = c + e_addi(0, 11, 1) + e_bl(allocOff - (thisOff + 48))      // [44] x0=alloc(width+1)
    c = c + e_movr(14, 0) + e_movr(1, 0)                            // [52] x14=buf; x1=cursor
    c = c + e_movz(3, 0)                                            // [60] i=0
    c = c + e_ldrbO(4, 10, 3) + e_cbz(4, 20) + e_strb(4, 1) + e_addi(1, 1, 1) + e_addi(3, 3, 1) + e_b(0 - 20)  // [64] .cl: copy s (no nul)
    c = c + e_subr(2, 11, 13)                                      // [88] .pad: x2=width-slen
    c = c + e_cbz(2, 20) + e_strb(12, 1) + e_addi(1, 1, 1) + e_subi(2, 2, 1) + e_b(0 - 16)  // [92] .fill: pad
    c = c + e_strb(31, 1)                                          // [112] .term: *x1=NUL
    c = c + e_movr(0, 14) + e_movr(30, 26) + e_ret()              // [116] return buf
    c = c + e_movr(0, 10) + e_movr(30, 26) + e_ret()              // [128] .rets: return s
    emit c
}
// kr_toupper(x0=s) -> new heap string with a-z uppercased. 112 bytes.
// x10=s x11=len x14=buf x26=lr. Copies+transforms in one pass.
func emitToUpper(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 0) + e_movz(11, 0)          // [0] lr; x10=s; len=0
    c = c + e_ldrbO(3, 10, 11) + e_cbz(3, 12) + e_addi(11, 11, 1) + e_b(0 - 12)  // [12] .sl: strlen -> x11
    c = c + e_addi(0, 11, 1) + e_bl(allocOff - (thisOff + 32))      // [28] x0=alloc(len+1)
    c = c + e_movr(14, 0) + e_movz(3, 0)                            // [36] x14=buf; i=0
    c = c + e_cmp(3, 11) + e_bge(48)                                // [44] .cl: i>=len -> .done (92)
    c = c + e_ldrbO(4, 10, 3)                                       // [52] w4=s[i]
    c = c + e_subi(5, 4, 97) + e_cmpi0(5) + e_blt(20)               // [56] c<'a' -> .store (84)
    c = c + e_subi(5, 4, 123) + e_cmpi0(5) + e_bge(8)               // [68] c>'z' -> .store (84)
    c = c + e_subi(4, 4, 32)                                        // [80] c -= 32
    c = c + e_strbR(4, 14, 3) + e_addi(3, 3, 1) + e_b(0 - 48)       // [84] .store: buf[i]=c; i++; -> .cl (44)
    c = c + e_strbR(31, 14, 11) + e_movr(0, 14) + e_movr(30, 26) + e_ret()  // [96] .done: buf[len]=0; return buf
    emit c
}
// kr_tolower(x0=s) -> new heap string with A-Z lowercased. 112 bytes.
func emitToLower(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 0) + e_movz(11, 0)          // [0]
    c = c + e_ldrbO(3, 10, 11) + e_cbz(3, 12) + e_addi(11, 11, 1) + e_b(0 - 12)  // [12] strlen
    c = c + e_addi(0, 11, 1) + e_bl(allocOff - (thisOff + 32))      // [28] alloc
    c = c + e_movr(14, 0) + e_movz(3, 0)                            // [36]
    c = c + e_cmp(3, 11) + e_bge(48)                                // [44] .cl
    c = c + e_ldrbO(4, 10, 3)                                       // [52]
    c = c + e_subi(5, 4, 65) + e_cmpi0(5) + e_blt(20)               // [56] c<'A' -> .store
    c = c + e_subi(5, 4, 91) + e_cmpi0(5) + e_bge(8)                // [68] c>'Z' -> .store
    c = c + e_addi(4, 4, 32)                                        // [80] c += 32
    c = c + e_strbR(4, 14, 3) + e_addi(3, 3, 1) + e_b(0 - 48)       // [84] .store
    c = c + e_strbR(31, 14, 11) + e_movr(0, 14) + e_movr(30, 26) + e_ret()  // [96] .done
    emit c
}
// kr_reverse(x0=s) -> new heap string reversed. 92 bytes. buf[i]=s[len-1-i].
func emitReverse(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 0) + e_movz(11, 0)          // [0]
    c = c + e_ldrbO(3, 10, 11) + e_cbz(3, 12) + e_addi(11, 11, 1) + e_b(0 - 12)  // [12] strlen -> x11
    c = c + e_addi(0, 11, 1) + e_bl(allocOff - (thisOff + 32))      // [28] alloc
    c = c + e_movr(14, 0) + e_movz(3, 0)                            // [36] buf; i=0
    c = c + e_cmp(3, 11) + e_bge(28)                                // [44] .cl: i>=len -> .done (76)
    c = c + e_subr(5, 11, 3) + e_subi(5, 5, 1) + e_ldrbO(4, 10, 5)  // [52] x5=len-1-i; w4=s[x5]
    c = c + e_strbR(4, 14, 3) + e_addi(3, 3, 1) + e_b(0 - 28)       // [64] buf[i]=w4; i++; -> .cl (44)
    c = c + e_strbR(31, 14, 11) + e_movr(0, 14) + e_movr(30, 26) + e_ret()  // [76] .done
    emit c
}
// kr_startswith(x1=s, x0=prefix) -> x0=1/0. 48 bytes. No alloc.
func emitStartsWith() {
    let c = e_movz(3, 0)                                            // [0] i=0
    c = c + e_ldrbO(4, 0, 3) + e_cbz(4, 24)                         // [4] .cl: pc=prefix[i]; ==0 -> .yes (32)
    c = c + e_ldrbO(5, 1, 3) + e_cmp(4, 5) + e_bne(20)              // [12] sc=s[i]; differ -> .no (40)
    c = c + e_addi(3, 3, 1) + e_b(0 - 24)                           // [24] i++; -> .cl (4)
    c = c + e_movz(0, 1) + e_ret()                                  // [32] .yes: x0=1
    c = c + e_movz(0, 0) + e_ret()                                  // [40] .no: x0=0
    emit c
}
// kr_endswith(x1=s, x0=suffix) -> x0=1/0. 104 bytes. Compares s tail.
func emitEndsWith() {
    let c = e_movz(6, 0)                                            // [0] slen=0
    c = c + e_ldrbO(3, 1, 6) + e_cbz(3, 12) + e_addi(6, 6, 1) + e_b(0 - 12)  // [4] strlen(s)->x6
    c = c + e_movz(7, 0)                                            // [20] suflen=0
    c = c + e_ldrbO(3, 0, 7) + e_cbz(3, 12) + e_addi(7, 7, 1) + e_b(0 - 12)  // [24] strlen(suffix)->x7
    c = c + e_cmp(7, 6) + e_bgt(52)                                 // [40] suflen>slen -> .no (96)
    c = c + e_subr(8, 6, 7) + e_movz(3, 0)                          // [48] start=slen-suflen; i=0
    c = c + e_ldrbO(4, 0, 3) + e_cbz(4, 28)                         // [56] .cl: suf[i]; ==0 -> .yes (88)
    c = c + e_addr(5, 8, 3) + e_ldrbO(9, 1, 5) + e_cmp(4, 9) + e_bne(20)  // [64] s[start+i]; differ -> .no (96)
    c = c + e_addi(3, 3, 1) + e_b(0 - 28)                           // [80] i++; -> .cl (56)
    c = c + e_movz(0, 1) + e_ret()                                  // [88] .yes
    c = c + e_movz(0, 0) + e_ret()                                  // [96] .no
    emit c
}
// kr_repeat(x1=s, x0=n) -> new heap string s repeated n times. 120 bytes.
// x10=s x11=n x6=slen x14=buf x12=k. Uses MUL for total length.
func emitRepeat(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 1) + e_movr(11, 0)          // [0] lr; x10=s; x11=n
    c = c + e_movz(6, 0)                                            // [12] slen=0
    c = c + e_ldrbO(3, 10, 6) + e_cbz(3, 12) + e_addi(6, 6, 1) + e_b(0 - 12)  // [16] strlen(s)->x6
    c = c + e_mul(0, 6, 11) + e_addi(0, 0, 1)                       // [32] x0 = slen*n + 1
    c = c + e_bl(allocOff - (thisOff + 40))                         // [40] x0=buf
    c = c + e_movr(14, 0) + e_movr(1, 0) + e_movz(12, 0)            // [44] x14=buf; x1=cursor; k=0
    c = c + e_cmp(12, 11) + e_bge(44)                               // [56] .outer: k>=n -> .term (104)
    c = c + e_movz(3, 0)                                            // [64] j=0
    c = c + e_cmp(3, 6) + e_bge(24)                                 // [68] .inner: j>=slen -> .nextk (96)
    c = c + e_ldrbO(4, 10, 3) + e_strb(4, 1) + e_addi(1, 1, 1) + e_addi(3, 3, 1) + e_b(0 - 24)  // [76] copy s[j]
    c = c + e_addi(12, 12, 1) + e_b(0 - 44)                         // [96] .nextk: k++; -> .outer (56)
    c = c + e_strb(31, 1) + e_movr(0, 14) + e_movr(30, 26) + e_ret()  // [104] .term: *x1=0; return buf
    emit c
}
// kr_contains(x1=s, x0=sub) -> x0=1/0. 120 bytes. Naive substring search.
func emitContains() {
    let c = e_movz(6, 0)                                            // [0] slen=0
    c = c + e_ldrbO(3, 1, 6) + e_cbz(3, 12) + e_addi(6, 6, 1) + e_b(0 - 12)  // [4] strlen(s)->x6
    c = c + e_movz(7, 0)                                            // [20] sublen=0
    c = c + e_ldrbO(3, 0, 7) + e_cbz(3, 12) + e_addi(7, 7, 1) + e_b(0 - 12)  // [24] strlen(sub)->x7
    c = c + e_movz(8, 0)                                            // [40] start=0
    c = c + e_addr(9, 8, 7) + e_cmp(9, 6) + e_bgt(60)               // [44] .outer: start+sublen>slen -> .no (112)
    c = c + e_movz(3, 0)                                            // [56] j=0
    c = c + e_cmp(3, 7) + e_bge(40)                                 // [60] .inner: j>=sublen -> .yes (104)
    c = c + e_addr(5, 8, 3) + e_ldrbO(4, 1, 5) + e_ldrbO(9, 0, 3) + e_cmp(4, 9) + e_bne(12)  // [68] s[start+j]!=sub[j] -> .nextstart (96)
    c = c + e_addi(3, 3, 1) + e_b(0 - 32)                           // [88] j++; -> .inner (60)
    c = c + e_addi(8, 8, 1) + e_b(0 - 56)                           // [96] .nextstart: start++; -> .outer (44)
    c = c + e_movz(0, 1) + e_ret()                                  // [104] .yes
    c = c + e_movz(0, 0) + e_ret()                                  // [112] .no
    emit c
}
// kr_indexof(x1=s, x0=sub) -> x0=position or -1. 120 bytes. Same search; returns start/-1.
func emitIndexOf() {
    let c = e_movz(6, 0)                                            // [0] slen=0
    c = c + e_ldrbO(3, 1, 6) + e_cbz(3, 12) + e_addi(6, 6, 1) + e_b(0 - 12)  // [4] strlen(s)->x6
    c = c + e_movz(7, 0)                                            // [20] sublen=0
    c = c + e_ldrbO(3, 0, 7) + e_cbz(3, 12) + e_addi(7, 7, 1) + e_b(0 - 12)  // [24] strlen(sub)->x7
    c = c + e_movz(8, 0)                                            // [40] start=0
    c = c + e_addr(9, 8, 7) + e_cmp(9, 6) + e_bgt(60)               // [44] .outer: start+sublen>slen -> .notfound (112)
    c = c + e_movz(3, 0)                                            // [56] j=0
    c = c + e_cmp(3, 7) + e_bge(40)                                 // [60] .inner: j>=sublen -> .found (104)
    c = c + e_addr(5, 8, 3) + e_ldrbO(4, 1, 5) + e_ldrbO(9, 0, 3) + e_cmp(4, 9) + e_bne(12)  // [68] mismatch -> .nextstart (96)
    c = c + e_addi(3, 3, 1) + e_b(0 - 32)                           // [88] j++; -> .inner (60)
    c = c + e_addi(8, 8, 1) + e_b(0 - 56)                           // [96] .nextstart: start++; -> .outer (44)
    c = c + e_movr(0, 8) + e_ret()                                  // [104] .found: return start
    c = c + e_movn(0, 0) + e_ret()                                  // [112] .notfound: return -1
    emit c
}
// kr_trim(x0=s) -> new heap string with leading/trailing chars <=32 stripped. 168 bytes.
func emitTrim(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 0) + e_movz(6, 0)           // [0] lr; x10=s; len=0
    c = c + e_ldrbO(3, 10, 6) + e_cbz(3, 12) + e_addi(6, 6, 1) + e_b(0 - 12)  // [12] strlen->x6
    c = c + e_movz(3, 0)                                            // [28] start=0
    c = c + e_cmp(3, 6) + e_bge(28)                                 // [32] .ls: start>=len -> .startdone (64)
    c = c + e_ldrbO(4, 10, 3) + e_subi(5, 4, 33) + e_cmpi0(5) + e_bge(12)  // [40] c>=33 -> .startdone (64)
    c = c + e_addi(3, 3, 1) + e_b(0 - 28)                           // [56] start++; -> .ls (32)
    c = c + e_movr(4, 6)                                            // [64] .startdone: end=len
    c = c + e_cmp(4, 3) + e_ble(32)                                 // [68] .le: end<=start -> .enddone (104)
    c = c + e_subi(5, 4, 1) + e_ldrbO(9, 10, 5) + e_subi(5, 9, 33) + e_cmpi0(5) + e_bge(12)  // [76] s[end-1]>=33 -> .enddone (104)
    c = c + e_subi(4, 4, 1) + e_b(0 - 32)                           // [96] end--; -> .le (68)
    c = c + e_subr(7, 4, 3) + e_addi(0, 7, 1)                       // [104] .enddone: newlen=end-start; x0=newlen+1
    c = c + e_bl(allocOff - (thisOff + 112)) + e_movr(14, 0)        // [112] alloc -> x14=buf
    c = c + e_movz(5, 0)                                            // [120] i=0
    c = c + e_cmp(5, 7) + e_bge(24)                                 // [124] .cp: i>=newlen -> .done (152)
    c = c + e_addr(9, 3, 5) + e_ldrbO(4, 10, 9) + e_strbR(4, 14, 5) + e_addi(5, 5, 1) + e_b(0 - 24)  // [132] buf[i]=s[start+i]
    c = c + e_strbR(31, 14, 7) + e_movr(0, 14) + e_movr(30, 26) + e_ret()  // [152] .done: buf[newlen]=0; return
    emit c
}
// kr_split(x1=list, x0=idx int) -> idx-th comma-separated element (fresh string). 160 bytes.
// x10=ptr x11=remaining x12=elem-start x13=len x9=',' x26=lr.
func emitSplit(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(11, 0) + e_movr(10, 1) + e_movz(9, 44)  // [0] lr; rem=idx; ptr=list; x9=','
    c = c + e_cmpi0(11) + e_beq(32)                                // [16] .skip: rem==0 -> .scan_setup (48)
    c = c + e_ldrb0(3, 10) + e_cbz(3, 112)                         // [24] c=[ptr]; c==0 -> .empty (140)
    c = c + e_addi(10, 10, 1) + e_cmp(3, 9) + e_bne(8)             // [32] ptr++; c!=',' -> .skipcont (48)
    c = c + e_subi(11, 11, 1)                                      // [44] rem--
    c = c + e_b(0 - 32)                                            // [48] .skipcont: -> .skip (16)
    c = c + e_movr(12, 10)                                         // [52] .scan_setup: elem start
    c = c + e_ldrb0(3, 10) + e_cbz(3, 20)                          // [56] .scan: c=[ptr]; c==0 -> .got_end (80)
    c = c + e_cmp(3, 9) + e_beq(12)                                // [64] c==',' -> .got_end (80)
    c = c + e_addi(10, 10, 1) + e_b(0 - 20)                        // [72] ptr++; -> .scan (56)
    c = c + e_subr(13, 10, 12) + e_addi(0, 13, 1)                  // [80] .got_end: len=ptr-start; x0=len+1
    c = c + e_bl(allocOff - (thisOff + 88))                        // [88] x0=buf
    c = c + e_movr(1, 0) + e_movz(5, 0)                            // [92] dst=buf; i=0
    c = c + e_cmp(5, 13) + e_bge(20)                               // [100] .cp: i>=len -> .cpdone (124)
    c = c + e_ldrbO(4, 12, 5) + e_strbR(4, 1, 5) + e_addi(5, 5, 1) + e_b(0 - 20)  // [108] dst[i]=start[i]
    c = c + e_strbR(31, 1, 13) + e_movr(0, 1) + e_movr(30, 26) + e_ret()  // [124] .cpdone: dst[len]=0; return
    c = c + e_movz(0, 1) + e_bl(allocOff - (thisOff + 144)) + e_strb(31, 0) + e_movr(30, 26) + e_ret()  // [140] .empty: ""
    emit c
}
// kr_getline(x0=idx, x1=s) -> idx-th '\n'-separated line (no trailing \n).
// POINTER-KEYED CACHE (ported from macos_arm64 BUILTIN_GETLINE): cache slots
// GB+40(ptr)/+48(idx)/+56(off) in the gcGlobals reserved region. Same string &
// cached_idx<=idx -> resume the line-skip from the cached line start (rem =
// idx-cache_idx) instead of rescanning from s -> sequential getLine (tokAt /
// codegen line-loops) is O(1) amortized, killing the O(n^2) that stalled
// self-host. Cache miss (other string or idx<cached) rescans from 0, always
// correct. GB = load_base + opOff (folded 0x7F00 into movk hi). 224 bytes.
func emitGetline(allocOff, opOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(4, 0) + e_movr(3, 1) + e_movz(9, 10)  // [0,4,8,12] lr; idx=x4; s=x3; x9='\n'
    c = c + e_movz(14, opOff % 65536) + e_movk16(14, 32512 + opOff / 65536)  // [16,20] x14 = GB (VBASE+opOff)
    c = c + e_ldr8(7, 14, 5) + e_ldr8(8, 14, 6) + e_ldr8(15, 14, 7)  // [24,28,32] cache ptr/idx/off
    c = c + e_movr(11, 4) + e_movr(10, 3)                          // [36,40] MISS default: rem=idx; ptr=s
    c = c + e_cmp(7, 3) + e_bne(20)                                // [44,48] cache_ptr!=s -> .skip (68)
    c = c + e_cmp(8, 4) + e_bgt(12)                                // [52,56] cache_idx>idx -> .skip (68)
    c = c + e_subr(11, 4, 8) + e_movr(10, 15)                      // [60,64] HIT: rem=idx-cache_idx; ptr=cache_off
    c = c + e_cmpi0(11) + e_beq(32)                                // [68,72] .skip: rem==0 -> .scan_setup (104)
    c = c + e_ldrb0(6, 10) + e_cbz(6, 124)                         // [76,80] c=[ptr]; c==0 -> .empty (204)
    c = c + e_addi(10, 10, 1) + e_cmp(6, 9) + e_bne(8)             // [84,88,92] ptr++; c!='\n' -> .skipcont (100)
    c = c + e_subi(11, 11, 1)                                      // [96] rem--
    c = c + e_b(0 - 32)                                            // [100] .skipcont: -> .skip (68)
    c = c + e_str8(3, 14, 5) + e_str8(4, 14, 6) + e_str8(10, 14, 7)  // [104,108,112] .scan_setup: cache=(s,idx,linestart)
    c = c + e_movr(12, 10)                                         // [116] x12 = line start
    c = c + e_ldrb0(6, 10) + e_cbz(6, 20)                          // [120,124] .scan: c=[ptr]; c==0 -> .got_end (144)
    c = c + e_cmp(6, 9) + e_beq(12)                                // [128,132] c=='\n' -> .got_end (144)
    c = c + e_addi(10, 10, 1) + e_b(0 - 20)                        // [136,140] ptr++; -> .scan (120)
    c = c + e_subr(13, 10, 12) + e_addi(0, 13, 1)                  // [144,148] .got_end: len=ptr-start; x0=len+1
    c = c + e_bl(allocOff - (thisOff + 152))                       // [152] x0=buf
    c = c + e_movr(1, 0) + e_movz(5, 0)                            // [156,160] dst=buf; i=0
    c = c + e_cmp(5, 13) + e_bge(20)                               // [164,168] .cp: i>=len -> .cpdone (188)
    c = c + e_ldrbO(4, 12, 5) + e_strbR(4, 1, 5) + e_addi(5, 5, 1) + e_b(0 - 20)  // [172,176,180,184] dst[i]=start[i]
    c = c + e_strbR(31, 1, 13) + e_movr(0, 1) + e_movr(30, 26) + e_ret()  // [188,192,196,200] .cpdone: dst[len]=0; return
    c = c + e_movz(0, 1) + e_bl(allocOff - (thisOff + 208)) + e_strb(31, 0) + e_movr(30, 26) + e_ret()  // [204,208,212,216,220] .empty: ""
    emit c
}
// kr_linecount(x0=s) -> # of '\n'-separated lines. 1 + internal newlines, trailing
// \n not counted; empty -> 0 (mirrors x86 kr_linecount). 76 bytes.
func emitLinecount() {
    let c = e_movr(1, 0) + e_movz(0, 0) + e_ldrb0(2, 1) + e_cbz(2, 60)  // [0,4,8,12] x1=cur; cnt=0; empty -> .ret(72)
    c = c + e_movz(0, 1) + e_movz(3, 10)                          // [16,20] cnt=1; x3='\n'
    c = c + e_ldrb0(2, 1) + e_cbz(2, 24)                          // [24,28] .loop: c=[x1]; 0 -> .check(52)
    c = c + e_cmp(2, 3) + e_bne(8) + e_addi(0, 0, 1)              // [32,36,40] c=='\n' -> cnt++
    c = c + e_addi(1, 1, 1) + e_b(0 - 24)                         // [44,48] .skip: x1++; -> .loop(24)
    c = c + e_subi(4, 1, 1) + e_ldrb0(2, 4) + e_cmp(2, 3) + e_bne(8)  // [52,56,60,64] .check: last=='\n'?
    c = c + e_subi(0, 0, 1)                                       // [68] trailing \n -> cnt--
    c = c + e_ret()                                              // [72] .ret
    emit c
}
// ── C-like raw allocator (mark/sweep-ready 16-byte header shared with the GC design) ──
// gcGlobals live at GB = load_base + opOff (64 reserved bytes at the start of the
// 64 MiB raw BSS region above the op-stack). Layout (qword slots):
//   [GB+0]=raw_next (bump cursor, 0=uninit), [GB+8]=freelist head,
//   [GB+16]=gcAllocated (live bytes), [GB+24]=gcAllocCount, [GB+32]=gcLimit.
// Per-alloc header: [ptr-16]=chain/freelist next, [ptr-8]=size<<2 (bit0 mark /
// bit1 sweep, upper 62 size). rawAlloc returns ptr (= block+16). Freelist-first
// (W stage-6-phase-2): first-fit a freed block >= n before bumping. 196 bytes.
func emitRawAlloc(opOff, thisOff) {
    let c = e_movz(10, opOff % 65536) + e_movk16(10, 32512 + opOff / 65536)  // [0,4] x10=GB
    c = c + e_addi(1, 0, 31) + e_movz(2, 4) + e_lsrv(1, 1, 2) + e_lslv(1, 1, 2)  // [8,12,16,20] x1=total=roundup16(n+16)
    // ── freelist first-fit (x6=prev-next-slot addr, x7=cur) ──
    c = c + e_addi(6, 10, 8) + e_ldr0(7, 6)                       // [24,28] x6=&freelist head; x7=cur
    c = c + e_cbz(7, 92) + e_ldr8(8, 7, 1) + e_movz(9, 2) + e_lsrv(8, 8, 9)  // [32,36,40,44] .fl: cur==0 -> .bump(124); x8=cursize
    c = c + e_cmp(8, 0) + e_bhs(16) + e_movr(6, 7) + e_ldr0(7, 7) + e_b(0 - 32)  // [48,52,56,60,64] cursize>=n -> .hit(68); else advance
    c = c + e_ldr0(9, 7) + e_str0(9, 6)                           // [68,72] .hit: unlink (prev.next = cur.next)
    c = c + e_addi(2, 8, 31) + e_movz(3, 4) + e_lsrv(2, 2, 3) + e_lslv(2, 2, 3)  // [76,80,84,88] x2=total of block
    c = c + e_ldr8(4, 10, 2) + e_addr(4, 4, 2) + e_str8(4, 10, 2)  // [92,96,100] allocated += total
    c = c + e_ldr8(4, 10, 3) + e_addi(4, 4, 1) + e_str8(4, 10, 3)  // [104,108,112] count += 1
    c = c + e_addi(0, 7, 16) + e_ret()                           // [116,120] return cur+16
    // ── bump path ──
    c = c + e_ldr0(3, 10) + e_cbnz(3, 12)                         // [124,128] .bump: x3=raw_next; !=0 -> .have(140)
    c = c + e_movz(3, (opOff + 96) % 65536) + e_movk16(3, 32512 + (opOff + 96) / 65536)  // [132,136] lazy init cursor=rawBase+96 (GB+64/72/80 = argc/argv/envp)
    c = c + e_addr(4, 3, 1) + e_str0(4, 10)                       // [140,144] .have: raw_next = cursor+total
    c = c + e_movz(5, 4) + e_lslv(6, 0, 5) + e_str8(6, 3, 1) + e_str0(31, 3)  // [148,152,156,160] hdr: [+8]=n<<2; [+0]=0
    c = c + e_ldr8(7, 10, 2) + e_addr(7, 7, 1) + e_str8(7, 10, 2)  // [164,168,172] allocated += total
    c = c + e_ldr8(7, 10, 3) + e_addi(7, 7, 1) + e_str8(7, 10, 3)  // [176,180,184] count += 1
    c = c + e_addi(0, 3, 16) + e_ret()                           // [188,192] return cursor+16
    emit c
}
// kr_rawfree(x0=ptr): read size from header, decrement live counters, push the
// block onto the freelist. No size arg (C free shape). 80 bytes.
func emitRawFree(opOff, thisOff) {
    let c = e_movz(10, opOff % 65536) + e_movk16(10, 32512 + opOff / 65536)  // [0,4] GB
    c = c + e_subi(1, 0, 16) + e_ldr8(2, 1, 1) + e_movz(3, 2) + e_lsrv(2, 2, 3)  // [8,12,16,20] hdr=ptr-16; x2=size
    c = c + e_addi(2, 2, 31) + e_movz(3, 4) + e_lsrv(2, 2, 3) + e_lslv(2, 2, 3)  // [24,28,32,36] x2=total
    c = c + e_ldr8(4, 10, 2) + e_subr(4, 4, 2) + e_str8(4, 10, 2)  // [40,44,48] allocated -= total
    c = c + e_ldr8(4, 10, 3) + e_subi(4, 4, 1) + e_str8(4, 10, 3)  // [52,56,60] count -= 1
    c = c + e_ldr8(5, 10, 1) + e_str0(5, 1) + e_str8(1, 10, 1)     // [64,68,72] push hdr to freelist
    c = c + e_ret()                                              // [76]
    emit c
}
// kr_rawrealloc(x0=ptr, x1=n) -> x0=new ptr. Grows via rawAlloc+copy+rawFree;
// returns ptr unchanged if n <= old size. Reads old size from header. 108 bytes.
func emitRawRealloc(rawallocOff, rawfreeOff, thisOff) {
    let c = e_movr(23, 30) + e_subi(2, 0, 16) + e_ldr8(3, 2, 1)   // [0,4,8] lr; hdr; x3=size+flags
    c = c + e_movz(4, 2) + e_lsrv(3, 3, 4)                        // [12,16] x3=oldsize
    c = c + e_cmp(1, 3) + e_ble(76)                               // [20,24] n<=oldsize -> .keep(100)
    c = c + e_movr(24, 0) + e_movr(25, 1) + e_movr(26, 3)         // [28,32,36] save old/n/oldsize
    c = c + e_movr(0, 1) + e_bl(rawallocOff - (thisOff + 44)) + e_movr(27, 0)  // [40,44,48] newptr=rawAlloc(n)
    c = c + e_movz(5, 0)                                          // [52] i=0
    c = c + e_cmp(5, 26) + e_bhs(20)                              // [56,60] .cp: i>=oldsize -> .cpdone(80)
    c = c + e_ldrbO(6, 24, 5) + e_strbR(6, 27, 5) + e_addi(5, 5, 1) + e_b(0 - 20)  // [64,68,72,76] new[i]=old[i]
    c = c + e_movr(0, 24) + e_bl(rawfreeOff - (thisOff + 84)) + e_movr(0, 27)  // [80,84,88] .cpdone: free old; x0=new
    c = c + e_movr(30, 23) + e_ret()                             // [92,96]
    c = c + e_movr(30, 23) + e_ret()                             // [100,104] .keep: return ptr
    emit c
}
// kr_count(x0=list) -> number of comma-separated elements (commas+1, or 0 if empty). 64 bytes.
func emitCount() {
    let c = e_ldrb0(3, 0) + e_cbz(3, 52)                           // [0] empty -> .zero (56)
    c = c + e_movz(1, 0) + e_movz(2, 0) + e_movz(9, 44)            // [8] commas=0; i=0; x9=','
    c = c + e_ldrbO(3, 0, 2) + e_cbz(3, 24)                        // [20] .cl: c=s[i]; c==0 -> .done (48)
    c = c + e_cmp(3, 9) + e_bne(8)                                 // [28] c!=',' -> .cont (40)
    c = c + e_addi(1, 1, 1)                                        // [36] commas++
    c = c + e_addi(2, 2, 1) + e_b(0 - 24)                          // [40] .cont: i++; -> .cl (20)
    c = c + e_addi(0, 1, 1) + e_ret()                             // [48] .done: x0=commas+1
    c = c + e_movz(0, 0) + e_ret()                                // [56] .zero: x0=0
    emit c
}
// kr_pow(x1=base, x0=exp) -> base^exp. 32 bytes. result=1; result*=base, exp times.
func emitPow() {
    let c = e_movz(2, 1)                                          // [0] result=1
    c = c + e_cmpi0(0) + e_beq(16)                                // [4] .lp: exp==0 -> .done (24)
    c = c + e_mul(2, 2, 1) + e_subi(0, 0, 1) + e_b(0 - 16)        // [12] result*=base; exp--; -> .lp (4)
    c = c + e_movr(0, 2) + e_ret()                                // [24] .done: x0=result
    emit c
}
// kr_range(x1=start, x0=end) -> comma-string "start,...,end-1". 156 bytes.
// Builds elements via kr_str_int. x25=v x11=end x12=buf x13=cursor x26=lr
// (all survive str_int, which clobbers x0-x6/x10/x24/x30).
func emitRange(allocOff, strIntOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(25, 1) + e_movr(11, 0)        // [0] lr; v=start; end
    c = c + e_subr(2, 0, 1) + e_cmpi0(2) + e_ble(116)            // [12] count=end-start; <=0 -> .empty (136)
    c = c + e_movz(3, 12) + e_mul(0, 2, 3) + e_addi(0, 0, 2)     // [24] x0 = count*12 + 2
    c = c + e_bl(allocOff - (thisOff + 36))                      // [36] x0=buf
    c = c + e_movr(12, 0) + e_movr(13, 0)                        // [40] buf base; cursor
    c = c + e_cmp(25, 11) + e_bge(68)                            // [48] .loop: v>=end -> .done (120)
    c = c + e_movr(0, 25) + e_bl(strIntOff - (thisOff + 60))     // [56] x0 = str(v)
    c = c + e_ldrb0(4, 0) + e_cbz(4, 20)                         // [64] .cp: c=*istr; ==0 -> .cpdone (88)
    c = c + e_strb(4, 13) + e_addi(0, 0, 1) + e_addi(13, 13, 1) + e_b(0 - 20)  // [72] *cursor=c; istr++; cursor++; -> .cp (64)
    c = c + e_addi(5, 25, 1) + e_cmp(5, 11) + e_bge(16)          // [88] .cpdone: v+1>=end -> .skipcomma (112)
    c = c + e_movz(4, 44) + e_strb(4, 13) + e_addi(13, 13, 1)    // [100] *cursor=','; cursor++
    c = c + e_addi(25, 25, 1) + e_b(0 - 68)                      // [112] .skipcomma: v++; -> .loop (48)
    c = c + e_strb(31, 13) + e_movr(0, 12) + e_movr(30, 26) + e_ret()  // [120] .done: *cursor=0; return buf
    c = c + e_movz(0, 1) + e_bl(allocOff - (thisOff + 140)) + e_strb(31, 0) + e_movr(30, 26) + e_ret()  // [136] .empty: ""
    emit c
}
// kr_sbnew() -> handle block [cap:8][len:8][data]. cap=256, len=0. 36 bytes.
func emitSbNew(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movz(0, 272)                       // [0] lr; size=16+256
    c = c + e_bl(allocOff - (thisOff + 8))                        // [8] x0=handle
    c = c + e_movz(1, 256) + e_str0(1, 0)                         // [12] [handle]=cap=256
    c = c + e_str8(31, 0, 1) + e_strbO(31, 0, 16)                 // [20] [handle+8]=len=0; data[0]=0
    c = c + e_movr(30, 26) + e_ret()                             // [28] return handle (x0)
    emit c
}
// kr_sbappend(x1=handle, x0=s) -> handle (possibly relocated). 176 bytes.
// x10=handle x11=s x12=slen x13=len (all survive the alloc in the grow path).
func emitSbAppend(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 1) + e_movr(11, 0)        // [0] lr; handle; s
    c = c + e_movz(12, 0)                                         // [12] slen=0
    c = c + e_ldrbO(3, 11, 12) + e_cbz(3, 12) + e_addi(12, 12, 1) + e_b(0 - 12)  // [16] strlen(s)->x12
    c = c + e_ldr8(13, 10, 1)                                     // [32] len=[handle+8]
    c = c + e_addr(4, 13, 12) + e_addi(4, 4, 1)                   // [36] need=len+slen+1
    c = c + e_ldr0(5, 10) + e_cmp(4, 5) + e_ble(64)               // [44] cap=[handle]; need<=cap -> .nogrow (116)
    c = c + e_movz(6, 2) + e_mul(6, 4, 6)                         // [56] newcap=need*2
    c = c + e_addi(0, 6, 16) + e_bl(allocOff - (thisOff + 68))    // [64] x0=alloc(newcap+16)=nb
    c = c + e_movr(7, 0) + e_movz(8, 0) + e_addi(14, 13, 16)      // [72] nb; i=0; count=len+16
    c = c + e_cmp(8, 14) + e_bge(20)                              // [84] .cpold: i>=count -> .cpolddone (108)
    c = c + e_ldrbO(3, 10, 8) + e_strbR(3, 7, 8) + e_addi(8, 8, 1) + e_b(0 - 20)  // [92] nb[i]=handle[i]
    c = c + e_str0(6, 7) + e_movr(10, 7)                          // [108] .cpolddone: [nb]=newcap; handle=nb
    c = c + e_addi(4, 10, 16) + e_addr(4, 4, 13)                  // [116] .nogrow: x4=handle+16+len (dst)
    c = c + e_movz(8, 0)                                          // [124] i=0
    c = c + e_cmp(8, 12) + e_bge(20)                              // [128] .cpapp: i>=slen -> .cpappdone (152)
    c = c + e_ldrbO(3, 11, 8) + e_strbR(3, 4, 8) + e_addi(8, 8, 1) + e_b(0 - 20)  // [136] dst[i]=s[i]
    c = c + e_addr(5, 13, 12) + e_str8(5, 10, 1)                  // [152] .cpappdone: newlen=len+slen; [handle+8]=newlen
    c = c + e_strbR(31, 4, 12)                                    // [160] dst[slen]=0
    c = c + e_movr(0, 10) + e_movr(30, 26) + e_ret()             // [164] return handle
    emit c
}
// kr_sbtostring(x0=handle) -> data ptr = handle+16. 8 bytes.
func emitSbToString() {
    emit e_addi(0, 0, 16) + e_ret()
}
// kr_eq(x0=a, x1=b) -> x0=1/0. Polymorphic: both pointers (>=VBASE) -> strcmp;
// kr_eq: numeric-aware "==". Mirrors x86 kr_cmpi dispatch: if BOTH operands are
// numeric (small int < VBASE, OR digit-only string via kr_isnum) -> compare
// atoi(a) vs atoi(b); else fall through to the original byte-compare body (handles
// both-ptr strcmp and mixed int/ptr -> unequal). Saves lr in x23; a=x24 b=x25.
// 208 bytes (numeric prefix 132 + original body 76).
func emitEq(atoiOff, isnumOff, thisOff) {
    let c = e_movr(23, 30) + e_movzHi(9, 32512)                   // [0,4] lr; x9=VBASE
    c = c + e_movr(24, 0) + e_movr(25, 1)                         // [8,12] x24=a x25=b
    c = c + e_cmp(24, 9) + e_blt(16)                              // [16,20] a<VBASE int -> .a_num (36)
    c = c + e_movr(0, 24) + e_bl(isnumOff - (thisOff + 28)) + e_cbz(0, 88)  // [24,28,32] isnum(a)? no -> .fallback (120)
    c = c + e_cmp(25, 9) + e_blt(16)                              // [36,40] .a_num: b<VBASE -> .both_num (56)
    c = c + e_movr(0, 25) + e_bl(isnumOff - (thisOff + 48)) + e_cbz(0, 68)  // [44,48,52] isnum(b)? no -> .fallback (120)
    c = c + e_movr(0, 24) + e_cmp(0, 9) + e_blt(8)                // [56,60,64] .both_num: a int -> .av (72)
    c = c + e_bl(atoiOff - (thisOff + 68))                        // [68] x0=atoi(a)
    c = c + e_movr(10, 0) + e_movr(0, 25)                         // [72,76] .av: x10=aval; x0=b
    c = c + e_cmp(0, 9) + e_blt(8)                                // [80,84] b int -> .bv (92)
    c = c + e_bl(atoiOff - (thisOff + 88))                        // [88] x0=atoi(b)
    c = c + e_movr(30, 23) + e_cmp(10, 0) + e_beq(12)             // [92,96,100] .bv: lr; aval==bval -> .eq (112)
    c = c + e_movz(0, 0) + e_ret()                                // [104,108] not equal
    c = c + e_movz(0, 1) + e_ret()                                // [112,116] .eq
    c = c + e_movr(0, 24) + e_movr(1, 25) + e_movr(30, 23)        // [120,124,128] .fallback: restore a,b,lr
    // ── original byte-compare body (self-relative branches, unchanged) ──
    c = c + e_movzHi(9, 32512)                                    // [132] x9=VBASE
    c = c + e_cmp(0, 9) + e_blt(44)                               // a<VBASE -> .numeric
    c = c + e_cmp(1, 9) + e_blt(36)                               // b<VBASE -> .numeric
    c = c + e_movz(2, 0)                                          // i=0
    c = c + e_ldrbO(3, 0, 2) + e_ldrbO(4, 1, 2) + e_cmp(3, 4) + e_bne(24)  // .sl: a[i] vs b[i]; differ -> .ne
    c = c + e_cbz(3, 28)                                          // a[i]==0 (both, equal) -> .eq
    c = c + e_addi(2, 2, 1) + e_b(0 - 24)                         // i++; -> .sl
    c = c + e_cmp(0, 1) + e_beq(12)                               // .numeric: a==b -> .eq
    c = c + e_movz(0, 0) + e_ret()                                // .ne: x0=0
    c = c + e_movz(0, 1) + e_ret()                                // .eq: x0=1
    emit c
}
// kr_istruthy(x0=v) -> x0=1/0. Mirrors x86 kr_istruthy: int (<VBASE) truthy iff
// !=0; string ptr (>=VBASE) truthy iff NOT one of "" / "0" / "false". 128 bytes.
// (3-term cap per `c = c +` line — long chains miscompile through the x86 seed.)
func emitIsTruthy() {
    let c = e_movzHi(9, 32512)                                    // [0]   x9 = VBASE
    c = c + e_cmp(0, 9) + e_blt(120)                              // [4,8] v<VBASE -> .int (128)
    c = c + e_movr(10, 0) + e_ldrb0(2, 10) + e_cbz(2, 124)        // [12,16,20] x10=ptr; b0=s[0]; ""->.falsy (144)
    c = c + e_addi(10, 10, 1) + e_subi(3, 2, 48) + e_cbnz(3, 12)  // [24,28,32] x10->s[1]; b0!='0' -> .notzero (44)
    c = c + e_ldrb0(3, 10) + e_cbz(3, 104)                        // [36,40] s[1]==0 -> "0" -> .falsy (144)
    c = c + e_subi(3, 2, 102) + e_cbnz(3, 88)                     // [44,48] .notzero: b0!='f' -> .truthy (136)
    c = c + e_ldrb0(3, 10) + e_subi(3, 3, 97) + e_cbnz(3, 76)     // [52,56,60] s[1]!='a' -> .truthy (136)
    c = c + e_addi(10, 10, 1) + e_ldrb0(3, 10) + e_subi(3, 3, 108) // [64,68,72] x10->s[2]; s[2]
    c = c + e_cbnz(3, 60)                                         // [76] !='l' -> .truthy (136)
    c = c + e_addi(10, 10, 1) + e_ldrb0(3, 10) + e_subi(3, 3, 115) // [80,84,88] s[3]
    c = c + e_cbnz(3, 44)                                         // [92] !='s' -> .truthy (136)
    c = c + e_addi(10, 10, 1) + e_ldrb0(3, 10) + e_subi(3, 3, 101) // [96,100,104] s[4]
    c = c + e_cbnz(3, 28)                                         // [108] !='e' -> .truthy (136)
    c = c + e_addi(10, 10, 1) + e_ldrb0(3, 10) + e_cbnz(3, 16)    // [112,116,120] s[5]!=0 -> .truthy (136)
    c = c + e_b(20)                                               // [124] "false" -> .falsy (144)
    c = c + e_cbz(0, 16)                                          // [128] .int: v==0 -> .falsy (144)
    c = c + e_b(4)                                                // [132] -> .truthy (136)
    c = c + e_movz(0, 1) + e_ret()                                // [136,140] .truthy
    c = c + e_movz(0, 0) + e_ret()                                // [144,148] .falsy
    emit c
}
// kr_index(x1=s, x0=idx) -> fresh 1-char string of s[idx], or "" when out of range. 92 bytes.
func emitIndex(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movz(2, 0)
    c = c + e_ldrbO(3, 1, 2) + e_cbz(3, 12) + e_addi(2, 2, 1) + e_b(0 - 12)
    c = c + e_cmpi0(0) + e_blt(44) + e_cmp(0, 2) + e_bhs(36)
    c = c + e_ldrbO(2, 1, 0) + e_movr(10, 2)
    c = c + e_movz(0, 2) + e_bl(allocOff - (thisOff + 52))
    c = c + e_strb(10, 0) + e_strbO(31, 0, 1)
    c = c + e_movr(30, 26) + e_ret()
    c = c + e_movz(0, 1) + e_bl(allocOff - (thisOff + 76))
    c = c + e_strbO(31, 0, 0) + e_movr(30, 26) + e_ret()
    emit c
}
// kr_readfile(x0=path) -> NUL-terminated contents. 152 bytes. aarch64 syscalls:
// openat=56(AT_FDCWD=-100), fstat=80(st_size@+48), read=63, close=57. 144B stack statbuf.
// NB: keep each `c = c +` line <=3 terms — the x86 backend MISCOMPILES long
// concat chains here (drops terms), so syscall instructions silently vanish.
func emitReadFile(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_subi(31, 31, 144)                  // [0,4] lr; sub sp,#144 (statbuf)
    c = c + e_movr(1, 0) + e_movn(0, 99)                          // [8,12] x1=path; x0=AT_FDCWD
    c = c + e_movz(2, 0) + e_movz(3, 0)                           // [16,20] O_RDONLY; mode 0
    c = c + e_movz(8, 56) + e_svc()                              // [24,28] openat
    c = c + e_cmpi0(0) + e_blt(92)                               // [32,36] fd<0 -> .err (128)
    c = c + e_movr(10, 0) + e_movr(0, 10)                        // [40,44] fd=x10; x0=fd
    c = c + e_addi(1, 31, 0) + e_movz(8, 80)                     // [48,52] statbuf=sp; fstat nr
    c = c + e_svc() + e_ldr8(11, 31, 6)                          // [56,60] fstat; size=[sp+48]
    c = c + e_addi(0, 11, 1) + e_bl(allocOff - (thisOff + 68))    // [64,68] buf = alloc(size+1)
    c = c + e_movr(12, 0) + e_movr(0, 10)                        // [72,76] buf; fd
    c = c + e_movr(1, 12) + e_movr(2, 11)                        // [80,84] buf; size
    c = c + e_movz(8, 63) + e_svc()                             // [88,92] read
    c = c + e_strbR(31, 12, 11) + e_movr(0, 10)                 // [96,100] buf[size]=0; fd
    c = c + e_movz(8, 57) + e_svc()                             // [104,108] close
    c = c + e_movr(0, 12) + e_addi(31, 31, 144)                 // [112,116] return buf; restore sp
    c = c + e_movr(30, 26) + e_ret()                           // [120,124]
    c = c + e_addi(31, 31, 144) + e_movz(0, 1)                 // [128,132] .err: restore sp; alloc(1)
    c = c + e_bl(allocOff - (thisOff + 136)) + e_strb(31, 0)    // [136,140] empty string
    c = c + e_movr(30, 26) + e_ret()                           // [144,148]
    emit c
}
func emitReadProc(allocOff, thisOff) {
    let c = e_movr(23, 30) + e_movr(1, 0) + e_movn(0, 99)       // [0,4,8] lr; path; AT_FDCWD
    c = c + e_movz(2, 0) + e_movz(3, 0)                         // [12,16] O_RDONLY; mode 0
    c = c + e_movz(8, 56) + e_svc()                                  // [20,24] openat
    c = c + e_cmpi0(0) + e_blt(100)                                  // [28,32] fd<0 -> .err(132)
    c = c + e_movr(24, 0) + e_movz(0, 0) + e_movk16(0, 4)      // [36,40,44] fd; size=256KB
    c = c + e_bl(allocOff - (thisOff + 48)) + e_movr(25, 0)     // [48,52] buf=alloc(size)
    c = c + e_movr(26, 0) + e_movz(27, 65535)                   // [56,60] cursor=buf; remaining
    c = c + e_movr(0, 24) + e_movr(1, 26) + e_movr(2, 27)       // [64,68,72] .loop: read(fd,cursor,remaining)
    c = c + e_movz(8, 63) + e_svc()                                  // [76,80] read
    c = c + e_cmpi0(0) + e_ble(16)                                    // [84,88] nread<=0 -> .done(104)
    c = c + e_addr(26, 26, 0) + e_subr(27, 27, 0)               // [92,96] cursor+=nread; remaining-=nread
    c = c + e_cbnz(27, 0 - 36)                                  // [100] remaining!=0 -> .loop(64)
    c = c + e_strb(31, 26) + e_movr(0, 24)                      // [104,108] .done: *cursor=0; fd
    c = c + e_movz(8, 57) + e_svc() + e_movr(0, 25)             // [112,116,120] close; return buf
    c = c + e_movr(30, 23) + e_ret()                            // [124,128]
    c = c + e_movz(0, 1) + e_bl(allocOff - (thisOff + 136))      // [132,136] .err: alloc(1)
    c = c + e_strb(31, 0) + e_movr(30, 23) + e_ret()            // [140,144,148] return ""
    emit c
}
// kr_writefile(x1=path, x0=content) -> 0. 96 bytes. openat(WRONLY|CREAT|TRUNC=577,
// mode 0644=420), write, close.
// NB: <=3 terms per line (x86-backend miscompile drops terms from long chains).
func emitWriteFile() {
    let c = e_movr(26, 30) + e_movr(10, 0)                        // [0,4] lr; content
    c = c + e_movz(11, 0)                                         // [8] len=0
    c = c + e_ldrbO(3, 10, 11) + e_cbz(3, 12)                     // [12,16] .sl: content[len]; ==0 -> openat (28)
    c = c + e_addi(11, 11, 1) + e_b(0 - 12)                       // [20,24] len++; -> .sl (12)
    c = c + e_movn(0, 99) + e_movz(2, 577)                        // [28,32] x0=AT_FDCWD; flags
    c = c + e_movz(3, 420) + e_movz(8, 56)                        // [36,40] mode 0644; openat nr
    c = c + e_svc() + e_movr(12, 0)                              // [44,48] openat; fd=x12
    c = c + e_movr(0, 12) + e_movr(1, 10)                        // [52,56] fd; content
    c = c + e_movr(2, 11) + e_movz(8, 64)                        // [60,64] len; write nr
    c = c + e_svc() + e_movr(0, 12)                             // [68,72] write; fd
    c = c + e_movz(8, 57) + e_svc()                            // [76,80] close
    c = c + e_movz(0, 0) + e_movr(30, 26)                      // [84,88] return 0
    c = c + e_ret()                                            // [92]
    emit c
}
// kr_writebytes(x0=hex content, x1=path) -> x0=1. Decodes "xHH" triples and
// writes the raw bytes (ELF output has embedded NULs, so kr_writefile cannot
// be used). 244 bytes. Mirrors the x86 backend's kr_writebytes.
func emitWriteBytes(allocOff, strlenOff, thisOff) {
    let c = e_movr(23, 30) + e_movr(24, 0)                        // [0,4] lr; content
    c = c + e_movn(0, 99) + e_movz(2, 577)                        // [8,12] AT_FDCWD; flags
    c = c + e_movz(3, 420) + e_movz(8, 56)                        // [16,20] mode; openat
    c = c + e_svc() + e_cmpi0(0) + e_blt(200)                     // [24,28,32] openat; fd<0 -> .err(232)
    c = c + e_movr(25, 0) + e_movr(0, 24)                         // [36,40] fd; content
    c = c + e_bl(strlenOff - (thisOff + 44))                      // [44] x0=len(content)
    c = c + e_addi(0, 0, 1) + e_bl(allocOff - (thisOff + 52))     // [48,52] size+1; buf
    c = c + e_movr(26, 0) + e_movr(27, 0) + e_movr(28, 24)        // [56,60,64] base; out; src
    c = c + e_ldrb0(2, 28) + e_cbz(2, 116)                        // [68,72] .loop: c; NUL -> .write(188)
    c = c + e_movz(3, 120) + e_cmp(2, 3) + e_bne(96)              // [76,80,84] 'x'? no -> .skip(180)
    c = c + e_addi(5, 28, 1) + e_ldrb0(2, 5)                      // [88,92] hi char
    c = c + e_movz(3, 65) + e_cmp(2, 3) + e_bhs(12)               // [96,100,104] >= 'A' -> .hi_letter(116)
    c = c + e_subi(2, 2, 48) + e_b(8)                             // [108,112] digit; -> .hi_done(120)
    c = c + e_subi(2, 2, 55)                                      // [116] .hi_letter
    c = c + e_movz(5, 4) + e_lslv(2, 2, 5)                        // [120,124] .hi_done: hi <<= 4
    c = c + e_addi(6, 28, 2) + e_ldrb0(3, 6)                      // [128,132] lo char
    c = c + e_movz(4, 65) + e_cmp(3, 4) + e_bhs(12)               // [136,140,144] >= 'A' -> .lo_letter(156)
    c = c + e_subi(3, 3, 48) + e_b(8)                             // [148,152] digit; -> .lo_done(160)
    c = c + e_subi(3, 3, 55)                                      // [156] .lo_letter
    c = c + e_orr(2, 2, 3) + e_strb(2, 27)                        // [160,164] .lo_done: byte; store
    c = c + e_addi(27, 27, 1) + e_addi(28, 28, 3) + e_b(0 - 108)  // [168,172,176] out++; src+=3; -> .loop(68)
    c = c + e_addi(28, 28, 1) + e_b(0 - 116)                      // [180,184] .skip: src++; -> .loop(68)
    c = c + e_subr(2, 27, 26) + e_movr(0, 25)                     // [188,192] .write: count; fd
    c = c + e_movr(1, 26) + e_movz(8, 64) + e_svc()               // [196,200,204] buf; write
    c = c + e_movr(0, 25) + e_movz(8, 57) + e_svc()               // [208,212,216] close
    c = c + e_movz(0, 1) + e_movr(30, 23) + e_ret()               // [220,224,228] return 1
    c = c + e_movz(0, 0) + e_movr(30, 23) + e_ret()               // [232,236,240] .err: return 0
    emit c
}
// Structs = a linked list of 24-byte nodes [name:8][val:8][prev:8]; env head is
// the most-recent node (NULL = empty). setField prepends; getField walks+strcmps.
// kr_setfield(x0=env, x1=name, x2=val) -> x0=new node. 44 bytes.
func emitSetField(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 0)                        // [0,4] lr; env
    c = c + e_movr(11, 1) + e_movr(12, 2)                         // [8,12] name; val
    c = c + e_movz(0, 24) + e_bl(allocOff - (thisOff + 20))       // [16,20] node=alloc(24)
    c = c + e_str0(11, 0) + e_str8(12, 0, 1)                      // [24,28] node[0]=name; node[8]=val
    c = c + e_str8(10, 0, 2) + e_movr(30, 26)                     // [32,36] node[16]=prev=env
    c = c + e_ret()                                              // [40]
    emit c
}
// kr_getfield(x1=env, x0=name) -> x0=val, or fresh "" if not found. 92 bytes.
func emitGetField(allocOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(11, 0) + e_movr(10, 1)        // [0,4,8] lr; name; cur=env
    c = c + e_cbz(10, 60)                                         // [12] .loop: cur==0 -> .notfound (72)
    c = c + e_ldr0(0, 10) + e_movz(2, 0)                          // [16,20] x0=cur.name; i=0
    c = c + e_ldrbO(3, 0, 2) + e_ldrbO(4, 11, 2)                  // [24,28] .sc: curname[i]; name[i]
    c = c + e_cmp(3, 4) + e_bne(16)                               // [32,36] differ -> .nomatch (52)
    c = c + e_cbz(3, 20) + e_addi(2, 2, 1)                        // [40,44] both 0 -> .match (60); i++
    c = c + e_b(0 - 24)                                           // [48] -> .sc (24)
    c = c + e_ldr8(10, 10, 2) + e_b(0 - 44)                       // [52,56] .nomatch: cur=prev; -> .loop (12)
    c = c + e_ldr8(0, 10, 1) + e_movr(30, 26) + e_ret()          // [60,64,68] .match: x0=cur.val; ret
    c = c + e_movz(0, 1) + e_bl(allocOff - (thisOff + 76))        // [72,76] .notfound: x0=alloc(1)
    c = c + e_strb(31, 0) + e_movr(30, 26) + e_ret()            // [80,84,88] *x0=0 (""); ret
    emit c
}
// kr_hasfield(x1=env, x0=name) -> x0=1/0. 72 bytes. No alloc.
func emitHasField() {
    let c = e_movr(11, 0) + e_movr(10, 1)                         // [0,4] name; cur=env
    c = c + e_cbz(10, 56)                                         // [8] .loop: cur==0 -> .no (64)
    c = c + e_ldr0(0, 10) + e_movz(2, 0)                          // [12,16] cur.name; i=0
    c = c + e_ldrbO(3, 0, 2) + e_ldrbO(4, 11, 2)                  // [20,24] .sc
    c = c + e_cmp(3, 4) + e_bne(16)                               // [28,32] differ -> .nomatch (48)
    c = c + e_cbz(3, 20) + e_addi(2, 2, 1)                        // [36,40] both 0 -> .yes (56); i++
    c = c + e_b(0 - 24)                                           // [44] -> .sc (20)
    c = c + e_ldr8(10, 10, 2) + e_b(0 - 44)                       // [48,52] .nomatch: cur=prev; -> .loop (8)
    c = c + e_movz(0, 1) + e_ret()                                // [56,60] .yes
    c = c + e_movz(0, 0) + e_ret()                                // [64,68] .no
    emit c
}
// kr_structfields(x0=env) -> "name,name,..." (head-first, trailing comma). 104 bytes.
// Builds via kr_plus. x26=cur x27=result x28="," x29=lr (all survive kr_plus/kr_alloc).
func emitStructFields(allocOff, plusOff, thisOff) {
    let c = e_movr(29, 30) + e_movr(26, 0)                        // [0,4] lr; cur=env
    c = c + e_movz(0, 2) + e_bl(allocOff - (thisOff + 12))        // [8,12] alloc(2) for ","
    c = c + e_movz(1, 44) + e_strb(1, 0)                          // [16,20] comma[0]=','
    c = c + e_strbO(31, 0, 1) + e_movr(28, 0)                     // [24,28] comma[1]=0; x28=comma
    c = c + e_movz(0, 1) + e_bl(allocOff - (thisOff + 36))        // [32,36] alloc(1) empty result
    c = c + e_strb(31, 0) + e_movr(27, 0)                         // [40,44] result[0]=0; result=""
    c = c + e_cbz(26, 44)                                         // [48] .loop: cur==0 -> .done (92)
    c = c + e_movr(0, 27) + e_ldr0(1, 26)                         // [52,56] a=result; b=cur.name
    c = c + e_bl(plusOff - (thisOff + 60)) + e_movr(27, 0)        // [60,64] result = result+name
    c = c + e_movr(0, 27) + e_movr(1, 28)                         // [68,72] a=result; b=","
    c = c + e_bl(plusOff - (thisOff + 76)) + e_movr(27, 0)        // [76,80] result = result+","
    c = c + e_ldr8(26, 26, 2) + e_b(0 - 40)                       // [84,88] cur=cur.prev; -> .loop (48)
    c = c + e_movr(0, 27) + e_movr(30, 29) + e_ret()             // [92,96,100] .done: return result
    emit c
}
// kr_plus(a=x0, b=x1) -> x0. Polymorphic +: both ints -> a+b; else convert each
// to a string (kr_str_int for the int side) and concat into a fresh heap buffer.
// kr_isnum: x0=string ptr -> 1 for a signed decimal integer string, else 0.
// 104 bytes. Used by numeric-aware equality/comparison/concatenation.
func emitIsnum() {
    let c = e_movzHi(9, 32512) + e_cmp(0, 9) + e_blt(88)
    c = c + e_movzHi(7, 38656) + e_cmp(0, 7) + e_bge(76)
    c = c + e_movr(2, 0) + e_ldrb0(3, 2) + e_cbz(3, 64)
    c = c + e_subi(3, 3, 45) + e_cbnz(3, 16)
    c = c + e_addi(2, 2, 1) + e_ldrb0(3, 2) + e_cbz(3, 44)
    c = c + e_movz(4, 10)
    c = c + e_ldrb0(3, 2) + e_cbz(3, 24)
    c = c + e_subi(3, 3, 48) + e_cmp(3, 4) + e_bhs(20)
    c = c + e_addi(2, 2, 1) + e_b(0 - 24)
    c = c + e_movz(0, 1) + e_ret()
    c = c + e_movz(0, 0) + e_ret()
    emit c
}
// kr_cmp(a=x0, b=x1) -> x0 = signed 3-way (a<b<0, ==0, a>b>0). Mirrors x86 kr_cmpi:
// both numeric (int OR digit-string) -> atoi(a)-atoi(b); else byte-wise strcmp sign.
// Backs LT/GT/LTE/GTE (they cmp the result vs 0). Saves lr x23; a=x24 b=x25. 144 bytes.
func emitCmp(atoiOff, isnumOff, thisOff) {
    let c = e_movr(23, 30) + e_movzHi(9, 32512)                  // [0,4] lr; x9=VBASE
    c = c + e_movr(24, 0) + e_movr(25, 1)                        // [8,12] x24=a x25=b
    c = c + e_cmp(24, 9) + e_blt(16)                             // [16,20] a<VBASE int -> .a_ok (36)
    c = c + e_movr(0, 24) + e_bl(isnumOff - (thisOff + 28)) + e_cbz(0, 72)  // [24,28,32] isnum(a)? no -> .strcmp (104)
    c = c + e_cmp(25, 9) + e_blt(16)                             // [36,40] .a_ok: b<VBASE -> .b_ok (56)
    c = c + e_movr(0, 25) + e_bl(isnumOff - (thisOff + 48)) + e_cbz(0, 52)  // [44,48,52] isnum(b)? no -> .strcmp (104)
    c = c + e_movr(0, 24) + e_cmp(0, 9) + e_blt(8)               // [56,60,64] .b_ok: a int -> .av (72)
    c = c + e_bl(atoiOff - (thisOff + 68))                       // [68] x0=atoi(a)
    c = c + e_movr(10, 0) + e_movr(0, 25)                        // [72,76] .av: x10=aval; x0=b
    c = c + e_cmp(0, 9) + e_blt(8)                               // [80,84] b int -> .bv (92)
    c = c + e_bl(atoiOff - (thisOff + 88))                       // [88] x0=atoi(b)
    c = c + e_movr(30, 23) + e_subr(0, 10, 0) + e_ret()          // [92,96,100] .bv: lr; aval-bval; ret
    c = c + e_cmp(24, 9) + e_blt(52)                             // [104,108] .strcmp: mixed guard
    c = c + e_cmp(25, 9) + e_blt(44)                             // [112,116]
    c = c + e_movr(30, 23) + e_movz(2, 0)                        // [120,124] lr; i=0
    c = c + e_ldrbO(3, 24, 2) + e_ldrbO(4, 25, 2) + e_subr(0, 3, 4)  // [128,132,136] .sl
    c = c + e_cbnz(0, 16) + e_cbz(3, 12) + e_addi(2, 2, 1) + e_b(0 - 24)  // [140,144,148,152]
    c = c + e_ret()                                             // [156] .ret
    c = c + e_movr(0, 24) + e_subr(0, 0, 25) + e_movr(30, 23) + e_ret() // [160..176] .mixed
    emit c
}
// kr_plus: numeric-aware "+". Mirrors x86 kr_plus: if BOTH operands are numeric
// (small int < VBASE, OR digit-only string via kr_isnum) -> int sum (kr_atoi each
// string side); else string concat. Saves lr in x23; VBASE in x9; a=x24 b=x25.
// 288 bytes (numeric prefix 112 + concat body 176).
func emitPlus(strIntOff, allocOff, atoiOff, isnumOff, thisOff) {
    let c = e_movr(23, 30) + e_movzHi(9, 32512)                                   // [0,4] lr; x9=VBASE
    c = c + e_movr(24, 0) + e_movr(25, 1)                                         // [8,12] x24=a x25=b
    c = c + e_cmp(24, 9) + e_blt(16)                                              // [16,20] a<VBASE int -> .a_ok(36)
    c = c + e_movr(0, 24) + e_bl(isnumOff - (thisOff + 28)) + e_cbz(0, 72)        // [24,28,32] isnum(a)? no -> .concat(104)
    c = c + e_cmp(25, 9) + e_blt(16)                                              // [36,40] .a_ok: b<VBASE -> .b_ok(56)
    c = c + e_movr(0, 25) + e_bl(isnumOff - (thisOff + 48)) + e_cbz(0, 52)        // [44,48,52] isnum(b)? no -> .concat(104)
    c = c + e_movr(0, 24) + e_cmp(0, 9) + e_blt(8)                                // [56,60,64] .b_ok: a int -> .av(72)
    c = c + e_bl(atoiOff - (thisOff + 68))                                        // [68] x0=atoi(a)
    c = c + e_movr(10, 0) + e_movr(0, 25)                                         // [72,76] .av: x10=aval; x0=b
    c = c + e_cmp(0, 9) + e_blt(8)                                                // [80,84] b int -> .bv(92)
    c = c + e_bl(atoiOff - (thisOff + 88))                                        // [88] x0=atoi(b)
    c = c + e_addr(0, 10, 0) + e_movr(30, 23) + e_ret()                           // [92,96,100] .bv: aval+bval; ret
    c = c + e_movr(0, 24) + e_movr(1, 25)                                         // [104,108] .concat: restore a,b
    c = c + e_movr(13, 1)                                                          // [112] x13=b
    c = c + e_cmp(0, 9) + e_bge(8) + e_bl(strIntOff - (thisOff + 124))            // conv a (int side only)
    c = c + e_movr(11, 0)                                                          // [as] sa
    c = c + e_movr(0, 13) + e_cmp(0, 9) + e_bge(8) + e_bl(strIntOff - (thisOff + 144))  // conv b (int side only)
    c = c + e_movr(12, 0)                                                          // [bs] sb
    c = c + e_movz(14, 0) + e_ldrbO(3, 11, 14) + e_cbz(3, 12) + e_addi(14, 14, 1) + e_b(0 - 12)  // strlen sa
    c = c + e_movz(16, 0) + e_ldrbO(3, 12, 16) + e_cbz(3, 12) + e_addi(16, 16, 1) + e_b(0 - 12)  // strlen sb
    c = c + e_addr(0, 14, 16) + e_addi(0, 0, 1) + e_bl(allocOff - (thisOff + 200)) + e_movr(17, 0)  // dst=alloc(lenA+lenB+1)
    c = c + e_movz(2, 0) + e_cmp(2, 14) + e_bhs(24) + e_ldrbO(3, 11, 2) + e_strb(3, 0) + e_addi(0, 0, 1) + e_addi(2, 2, 1) + e_b(0 - 24)  // copy sa
    c = c + e_movz(2, 0) + e_cmp(2, 16) + e_bhs(24) + e_ldrbO(3, 12, 2) + e_strb(3, 0) + e_addi(0, 0, 1) + e_addi(2, 2, 1) + e_b(0 - 24)  // copy sb
    c = c + e_strb(31, 0) + e_movr(0, 17) + e_movr(30, 23) + e_ret()              // NUL; return dst
    emit c
}
func emitCoerce2(atoiOff, thisOff) {
    let c = e_movr(10, 0) + e_movr(11, 1)
    c = c + e_bl(atoiOff - (thisOff + 12))
    c = c + e_movr(10, 0) + e_movr(0, 11)
    c = c + e_bl(atoiOff - (thisOff + 24))
    emit c
}
// Forced string concatenation for CAT/interpolation. x0=a, x1=b -> fresh string.
func emitConcat(strIntOff, allocOff, thisOff) {
    let c = e_movr(23, 30) + e_movzHi(9, 32512) + e_movr(13, 1)
    c = c + e_cmp(0, 9) + e_bge(8) + e_bl(strIntOff - (thisOff + 20))
    c = c + e_movr(11, 0) + e_movr(0, 13) + e_cmp(0, 9)
    c = c + e_bge(8) + e_bl(strIntOff - (thisOff + 40)) + e_movr(12, 0)
    c = c + e_movz(14, 0) + e_ldrbO(3, 11, 14) + e_cbz(3, 12)
    c = c + e_addi(14, 14, 1) + e_b(0 - 12)
    c = c + e_movz(16, 0) + e_ldrbO(3, 12, 16) + e_cbz(3, 12)
    c = c + e_addi(16, 16, 1) + e_b(0 - 12)
    c = c + e_addr(0, 14, 16) + e_addi(0, 0, 1)
    c = c + e_bl(allocOff - (thisOff + 96)) + e_movr(17, 0)
    c = c + e_movz(2, 0) + e_cmp(2, 14) + e_bhs(24)
    c = c + e_ldrbO(3, 11, 2) + e_strb(3, 0) + e_addi(0, 0, 1)
    c = c + e_addi(2, 2, 1) + e_b(0 - 24)
    c = c + e_movz(2, 0) + e_cmp(2, 16) + e_bhs(24)
    c = c + e_ldrbO(3, 12, 2) + e_strb(3, 0) + e_addi(0, 0, 1)
    c = c + e_addi(2, 2, 1) + e_b(0 - 24)
    c = c + e_strb(31, 0) + e_movr(0, 17) + e_movr(30, 23) + e_ret()
    emit c
}
// kp dispatch, extracted from the driver so the huge `just run` stays small enough
// for the x86 backend to compile correctly (a large-function miscompile drops/garbles
// statements). Pops arg; pointer -> print, int -> kr_str_int then print; push dummy 0.
// kp dispatch helper (x0 = value in; prints it; preserves x20/x19). The op-stack
// pop/push stays in the driver — only the x20-free dispatch lives here, since
// add/sub x20 inside an emit* helper triggers an x86-backend miscompile. 32 bytes.
func emitKpDisp(thisOff, siOff, prOff) {
    let c = e_movr(25, 30)
    c = c + e_movzHi(9, 32512)
    c = c + e_cmp(0, 9)
    c = c + e_bge(8)
    c = c + e_bl(siOff - (thisOff + 16))
    c = c + e_bl(prOff - (thisOff + 20))
    c = c + e_movr(30, 25)
    c = c + e_ret()
    emit c
}
// kr_atoi: x0=string ptr -> x0=parsed signed decimal prefix. Stops at the
// first non-digit (so "13;f64" -> 13). Int-safe: a small int (< VBASE)
// passes through unchanged. 104 bytes.
func emitAtoi() {
    let c = e_movzHi(9, 32512) + e_cmp(0, 9) + e_bge(8)
    c = c + e_ret() + e_movzHi(7, 38656) + e_cmp(0, 7) + e_blt(8)
    c = c + e_ret() + e_movr(1, 0) + e_ldrb0(2, 1)
    c = c + e_subi(3, 2, 45) + e_cmpi0(3) + e_cset(6, 1)
    c = c + e_cbz(6, 8) + e_addi(1, 1, 1)
    c = c + e_movz(0, 0) + e_movz(4, 10)
    c = c + e_ldrb0(2, 1) + e_cbz(2, 36)
    c = c + e_subi(3, 2, 48) + e_cmp(3, 4) + e_bhs(24)
    c = c + e_mul(0, 0, 4) + e_subi(2, 2, 48) + e_addr(0, 0, 2)
    c = c + e_addi(1, 1, 1) + e_b(0 - 36)
    c = c + e_cbz(6, 8) + e_subr(0, 31, 0) + e_ret()
    emit c
}
// kr_substring: x0=s ptr, x1=start, x2=end -> x0=new heap string s[start:end].
func emitSubstr(allocOff, thisOff) {
    let c = e_movr(26, 30)                                     // save x30 (clobbered by bl kr_alloc)
    c = c + e_cmpi0(1) + e_bge(8) + e_movz(1, 0)
    c = c + e_cmp(2, 1) + e_bge(8) + e_movr(2, 1)
    c = c + e_movz(5, 0) + e_ldrbO(6, 0, 5) + e_cbz(6, 12)
    c = c + e_addi(5, 5, 1) + e_b(0 - 12)
    c = c + e_cmp(2, 5) + e_ble(8) + e_movr(2, 5)
    c = c + e_subr(3, 2, 1) + e_addr(4, 0, 1)                  // x3=len=end-start, x4=src=s+start
    c = c + e_movr(10, 3) + e_movr(11, 4) + e_addi(0, 3, 1)    // save len/src, x0=size=len+1
    c = c + e_bl(allocOff - (thisOff + 80))                    // x0=dst (clobbers x0/x15/x22/x30)
    c = c + e_movz(5, 0) + e_cmp(5, 10) + e_bhs(20)            // i=0; .cl: i<len? no -> .done
    c = c + e_ldrbO(6, 11, 5) + e_strbR(6, 0, 5) + e_addi(5, 5, 1) + e_b(0 - 20) // dst[i]=src[i]; i++
    c = c + e_strbR(31, 0, 10) + e_movr(30, 26) + e_ret()      // .done: dst[len]=0; restore x30; ret
    emit c
}
// kr_print: x0=ptr -> write the NUL-terminated string then a newline.
func emitPrint(nlOff) {
    let lo = nlOff % 65536
    let hi = 32512 + nlOff / 65536              // fold the 0x7F000000 load base
    let c = e_movr(1, 0) + e_movz(2, 0)
    c = c + e_ldrbO(3, 1, 2) + e_cbz(3, 12) + e_addi(2, 2, 1) + e_b(0 - 12)           // strlen
    c = c + e_movz(0, 1) + e_movz(8, 64) + e_svc()                                    // write(1,buf,len)
    c = c + e_movz(1, lo) + e_movk16(1, hi) + e_movz(2, 1) + e_movz(0, 1) + e_movz(8, 64) + e_svc() + e_ret()
    emit c
}
// kr_argcount() -> argc-1 (user args, excludes program name). argc stashed at
// GB+64 by _start. 20 bytes.
func emitArgcount(opOff) {
    let c = e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536)  // x9 = GB
    c = c + e_ldr8(0, 9, 8)                       // x0 = argc (GB+64)
    c = c + e_subi(0, 0, 1)                        // argc - 1 (skip argv[0])
    c = c + e_ret()
    emit c
}
// kr_arg(x0=idx) -> argv[idx+1] as a C-string ptr (idx+1 skips program name).
// argv base stashed at GB+72 by _start. 36 bytes.
func emitArg(opOff) {
    let c = e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536)  // x9 = GB
    c = c + e_ldr8(1, 9, 9)                        // x1 = argv ptr (GB+72)
    c = c + e_addi(0, 0, 1)                        // idx + 1
    c = c + e_movz(2, 3) + e_lslv(0, 0, 2)         // x0 = (idx+1) << 3  (qword index)
    c = c + e_addr(1, 1, 0)                         // x1 = &argv[idx+1]
    c = c + e_ldr0(0, 1)                            // x0 = argv[idx+1]
    c = c + e_ret()
    emit c
}
// kr_printerr: x0=ptr -> write the NUL-terminated string + newline to fd 2.
// Same shape as kr_print but fd=2 (stderr). 64 bytes.
func emitPrinterr(nlOff) {
    let lo = nlOff % 65536
    let hi = 32512 + nlOff / 65536
    let c = e_movr(1, 0) + e_movz(2, 0)
    c = c + e_ldrbO(3, 1, 2) + e_cbz(3, 12) + e_addi(2, 2, 1) + e_b(0 - 12)           // strlen
    c = c + e_movz(0, 2) + e_movz(8, 64) + e_svc()                                    // write(2,buf,len)
    c = c + e_movz(1, lo) + e_movk16(1, hi) + e_movz(2, 1) + e_movz(0, 2) + e_movz(8, 64) + e_svc() + e_ret()
    emit c
}
// kr_isdigit: x0=ptr to string -> 1 if first byte is '0'..'9', else 0. 32 bytes.
// (c - '0') unsigned >= 10 -> not a digit (also catches bytes < '0' via wrap).
func emitIsdigit() {
    let c = e_ldrb0(1, 0) + e_subi(1, 1, 48)      // w1 = [x0] - '0'
    c = c + e_movz(2, 10) + e_movz(0, 0)          // x2=10; default result 0
    c = c + e_cmp(1, 2) + e_bhs(8)                // (c-'0') >= 10 unsigned -> skip (not digit)
    c = c + e_movz(0, 1)                          // digit -> 1
    c = c + e_ret()
    emit c
}
// kr_strlen: x0=ptr -> x0=length (bytes before NUL). 32 bytes. (x9/x10 scratch)
func emitStrlen() {
    let c = e_movr(9, 0) + e_movz(0, 0)                       // [0,4] x9=ptr; len=0
    c = c + e_ldrb0(10, 9) + e_cbz(10, 16)                    // [8,12] .l: w10=[x9]; 0 -> .d(28)
    c = c + e_addi(9, 9, 1) + e_addi(0, 0, 1) + e_b(0 - 16)   // [16,20,24] x9++; len++; -> .l(8)
    c = c + e_ret()                                           // [28] .d
    emit c
}
// kr_replace(x0=s, x1=find, x2=rep) -> new string with all `find` replaced by
// `rep`. Empty find returns s. Alloc upper bound ls*(lr+1)+1. 228 bytes.
// Held across the alloc bl (which clobbers x0-x10): s/find/rep/lf/lr in
// x23-x27 (untouched by kr_strlen/kr_rawalloc); lr saved in x21; buf in x16.
func emitReplace(strlenOff, allocOff, thisOff) {
    let c = e_movr(21, 30)                                    // [0] save lr
    c = c + e_movr(23, 0) + e_movr(24, 1) + e_movr(25, 2)     // [4,8,12] s; find; rep
    c = c + e_movr(0, 24) + e_bl(strlenOff - (thisOff + 20)) + e_movr(26, 0)  // [16,20,24] lf = strlen(find)
    c = c + e_cbz(26, 188)                                    // [28] lf==0 -> .ret_s (216)
    c = c + e_movr(0, 25) + e_bl(strlenOff - (thisOff + 36)) + e_movr(27, 0)  // [32,36,40] lr = strlen(rep)
    c = c + e_movr(0, 23) + e_bl(strlenOff - (thisOff + 48)) + e_movr(11, 0)  // [44,48,52] ls = strlen(s)
    c = c + e_addi(0, 27, 1) + e_mul(0, 11, 0) + e_addi(0, 0, 1)              // [56,60,64] bufsize = ls*(lr+1)+1
    c = c + e_bl(allocOff - (thisOff + 68))                   // [68] x0 = buf
    c = c + e_movr(16, 0) + e_movr(28, 0)                     // [72,76] buf=x16; dst=x28 (src stays in x23=s)
    c = c + e_ldrb0(10, 23) + e_cbz(10, 116)                  // [80,84] .scan: *src; 0 -> .done (200)
    c = c + e_movr(9, 23) + e_movr(12, 24) + e_movr(13, 26)   // [88,92,96] p=src; q=find; n=lf
    c = c + e_cbz(13, 36)                                     // [100] .mc: n==0 -> .match (136)
    c = c + e_ldrb0(14, 9) + e_ldrb0(15, 12)                  // [104,108] *p, *q
    c = c + e_cmp(14, 15) + e_bne(64)                         // [112,116] differ -> .nomatch (180)
    c = c + e_addi(9, 9, 1) + e_addi(12, 12, 1) + e_subi(13, 13, 1) + e_b(0 - 32)  // [120,124,128,132] -> .mc (100)
    c = c + e_movr(12, 25) + e_movr(13, 27)                   // [136,140] .match: q=rep; n=lr
    c = c + e_cbz(13, 28)                                     // [144] .cprep: n==0 -> .cprepdone (172)
    c = c + e_ldrb0(14, 12) + e_strb(14, 28) + e_addi(12, 12, 1) + e_addi(28, 28, 1) + e_subi(13, 13, 1) + e_b(0 - 24)  // [148..168] dst[k]=rep[k] -> .cprep (144)
    c = c + e_addr(23, 23, 26) + e_b(0 - 96)                  // [172,176] .cprepdone: src += lf; -> .scan (80)
    c = c + e_ldrb0(14, 23) + e_strb(14, 28) + e_addi(23, 23, 1) + e_addi(28, 28, 1) + e_b(0 - 116)  // [180..196] .nomatch: *dst++=*src++; -> .scan (80)
    c = c + e_strb(31, 28) + e_movr(0, 16) + e_movr(30, 21) + e_ret()  // [200,204,208,212] .done: *dst=0; x0=buf; ret
    c = c + e_movr(0, 23) + e_movr(30, 21) + e_ret()          // [216,220,224] .ret_s: x0=s; ret
    emit c
}
// kr_environ(x0=name) -> ptr to env var value ("name=VALUE" -> &VALUE), or a
// fresh "" if unset. envp stashed at GB+80 by _start. 120 bytes.
func emitEnviron(opOff, allocOff, thisOff) {
    let c = e_movr(21, 30)                                    // [0] save lr (for not-found alloc)
    c = c + e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536)  // [4,8] x9=GB
    c = c + e_ldr8(9, 9, 10)                                  // [12] x9 = envp (GB+80)
    c = c + e_ldr0(10, 9) + e_cbz(10, 80)                     // [16,20] .loop: entry=*envp; 0 -> .notfound(100)
    c = c + e_movr(11, 0) + e_movr(12, 10)                    // [24,28] np=name; ep=entry
    c = c + e_ldrb0(13, 11) + e_cbz(13, 28)                   // [32,36] .cmp: nc=[np]; 0 -> .nameend(64)
    c = c + e_ldrb0(14, 12) + e_cmp(13, 14) + e_bne(44)       // [40,44,48] ec=[ep]; differ -> .next(92)
    c = c + e_addi(11, 11, 1) + e_addi(12, 12, 1) + e_b(0 - 28)  // [52,56,60] np++; ep++; -> .cmp(32)
    c = c + e_ldrb0(14, 12) + e_movz(15, 61) + e_cmp(14, 15) + e_bne(16)  // [64,68,72,76] .nameend: [ep]=='='? no -> .next(92)
    c = c + e_addi(0, 12, 1) + e_movr(30, 21) + e_ret()       // [80,84,88] x0=&value; ret
    c = c + e_addi(9, 9, 8) + e_b(0 - 80)                     // [92,96] .next: envp++; -> .loop(16)
    c = c + e_movz(0, 1) + e_bl(allocOff - (thisOff + 104)) + e_strb(31, 0) + e_movr(30, 21) + e_ret()  // [100,104,108,112,116] .notfound: ""
    emit c
}
// kr_exec(x0=cmd) -> child stdout as a NUL-terminated heap string. pipe2 +
// clone(SIGCHLD) + dup3 + execve(/bin/sh -c cmd, envp); parent read-loops into
// a 64 KiB buffer, closes both ends, reaps with wait4. 364 bytes. (syscalls:
// read=63, close=57, pipe2=59, dup3=24, clone=220, execve=221, wait4=260,
// exit=93)
func emitExec(opOff, allocOff, thisOff) {
    let c = e_movr(21, 30) + e_subi(31, 31, 96)              // [0,4] save lr; frame
    c = c + e_movz(5, 25135) + e_movk16(5, 28265) + e_movk32(5, 29487) + e_movk48(5, 104) + e_str0(5, 31)  // [8..24] "/bin/sh\0" -> [sp+0]
    c = c + e_movz(5, 25389) + e_str8(5, 31, 1)             // [28,32] "-c\0" -> [sp+8]
    c = c + e_addi(5, 31, 0) + e_str8(5, 31, 2)             // [36,40] argv[0]=&"/bin/sh" -> [sp+16]
    c = c + e_addi(5, 31, 8) + e_str8(5, 31, 3)             // [44,48] argv[1]=&"-c" -> [sp+24]
    c = c + e_str8(0, 31, 4) + e_str8(31, 31, 5)            // [52,56] argv[2]=cmd; argv[3]=NULL -> [sp+32],[sp+40]
    c = c + e_addi(0, 31, 48) + e_movz(1, 0) + e_movz(8, 59) + e_svc()  // [60..72] pipe2(&pipefd@sp+48, 0)
    c = c + e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536) + e_ldr8(9, 9, 10)  // [76,80,84] x9 = envp (GB+80)
    c = c + e_movz(0, 17) + e_movz(1, 0) + e_movz(2, 0) + e_movz(3, 0) + e_movz(4, 0) + e_movz(8, 220) + e_svc()  // [88..112] clone(SIGCHLD,0,0,0,0)
    c = c + e_cbz(0, 160)                                   // [116] x0==0 -> .child (276)
    // parent: close write end, alloc 64K+1, read-loop, close read end, wait4
    c = c + e_str8(0, 31, 7)                                // [120] [sp+56]=pid
    c = c + e_movz(1, 48) + e_ldrwO(0, 31, 1)           // [124,128] w0=pipefd[0] (read)
    c = c + e_movr(27, 0)                                   // [132] x27=read fd
    c = c + e_movz(1, 52) + e_ldrwO(0, 31, 1)           // [136,140] w0=pipefd[1] (write)
    c = c + e_movz(8, 57) + e_svc()                         // [144,148] close(write)
    c = c + e_movz(0, 1) + e_movk16(0, 1)                   // [152,156] x0=65537
    c = c + e_bl(allocOff - (thisOff + 160))                // [160] x0=buf
    c = c + e_movr(23, 0) + e_movr(24, 0)                   // [164,168] x23=buf base; x24=cursor
    c = c + e_movz(25, 0) + e_movk16(25, 1)                 // [172,176] x25=65536 (remaining)
    // .loop (180): read(fd, cursor, remaining)
    c = c + e_movr(0, 27) + e_movr(1, 24) + e_movr(2, 25) + e_movz(8, 63) + e_svc()  // [180..196]
    c = c + e_cmpi0(0) + e_ble(16)                          // [200,204] n<=0 -> .done (220)
    c = c + e_addr(24, 24, 0) + e_subr(25, 25, 0)           // [208,212] cursor+=n; remaining-=n
    c = c + e_b(0 - 36)                                     // [216] -> .loop (180)
    // .done (220)
    c = c + e_strb(31, 24)                                  // [220] *cursor=0
    c = c + e_movr(0, 27) + e_movz(8, 57) + e_svc()         // [224,228,232] close(read)
    c = c + e_ldr8(0, 31, 7)                                // [236] x0=pid
    c = c + e_addi(1, 31, 64) + e_movz(2, 0) + e_movz(3, 0) + e_movz(8, 260) + e_svc()  // [240..256] wait4(pid,&status,0,0)
    c = c + e_movr(0, 23)                                   // [260] return buf
    c = c + e_addi(31, 31, 96) + e_movr(30, 21) + e_ret()   // [264,268,272] restore; ret
    // .child (276): dup3(write,1,0); close both; execve; exit(127)
    c = c + e_movz(1, 48) + e_ldrwO(0, 31, 1)           // [276,280] w0=pipefd[0]
    c = c + e_movz(8, 57) + e_svc()                         // [284,288] close(read)
    c = c + e_movz(1, 52) + e_ldrwO(0, 31, 1)           // [292,296] w0=pipefd[1]
    c = c + e_movz(1, 1) + e_movz(2, 0) + e_movz(8, 24) + e_svc()  // [300..312] dup3(write,1,0)
    c = c + e_movz(1, 52) + e_ldrwO(0, 31, 1)           // [316,320] w0=pipefd[1]
    c = c + e_movz(8, 57) + e_svc()                         // [324,328] close(write)
    c = c + e_addi(0, 31, 0) + e_addi(1, 31, 16) + e_movr(2, 9) + e_movz(8, 221) + e_svc()  // [332..348] execve
    c = c + e_movz(0, 127) + e_movz(8, 93) + e_svc()        // [352,356,360] execve failed -> exit(127)
    emit c
}

// kr_shellrun(x0=cmd) -> child exit code. fork (clone SIGCHLD) + execve(/bin/sh
// -c cmd, envp) + wait4. Builds "/bin/sh\0", "-c\0" and the argv vector on a
// 64-byte stack frame. envp from GB+80. 196 bytes. (syscalls: clone=220,
// execve=221, wait4=260, exit=93)
func emitShellrun(opOff, allocOff, strIntOff, thisOff) {
    let c = e_movr(21, 30) + e_subi(31, 31, 64)              // [0,4] save lr; frame
    c = c + e_movz(5, 25135) + e_movk16(5, 28265) + e_movk32(5, 29487) + e_movk48(5, 104) + e_str0(5, 31)  // [8,12,16,20,24] "/bin/sh\0" -> [sp+0]
    c = c + e_movz(5, 25389) + e_str8(5, 31, 1)             // [28,32] "-c\0" -> [sp+8]
    c = c + e_addi(5, 31, 0) + e_str8(5, 31, 2)             // [36,40] argv[0]=&"/bin/sh" -> [sp+16]
    c = c + e_addi(5, 31, 8) + e_str8(5, 31, 3)             // [44,48] argv[1]=&"-c" -> [sp+24]
    c = c + e_str8(0, 31, 4) + e_str8(31, 31, 5)            // [52,56] argv[2]=cmd; argv[3]=NULL -> [sp+32],[sp+40]
    c = c + e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536) + e_ldr8(9, 9, 10)  // [60,64,68] x9 = envp (GB+80)
    c = c + e_movz(0, 17) + e_movz(1, 0) + e_movz(2, 0) + e_movz(3, 0) + e_movz(4, 0) + e_movz(8, 220) + e_svc()  // [72..96] clone(SIGCHLD,0,0,0,0)
    c = c + e_cbz(0, 60)                                    // [100] x0==0 -> .child (160)
    c = c + e_addi(1, 31, 48) + e_movz(2, 0) + e_movz(3, 0) + e_movz(8, 260) + e_svc()  // [104..120] parent: wait4(pid, &status@sp+48, 0, 0)
    c = c + e_ldr8(0, 31, 6) + e_movz(6, 8) + e_lsrv(0, 0, 6) + e_movz(6, 255) + e_and(0, 0, 6)  // [124..140] code = (status>>8)&0xff
    c = c + e_bl(strIntOff - (thisOff + 144))                  // [144] decimal exit-code string
    c = c + e_addi(31, 31, 64) + e_movr(30, 21) + e_ret()   // [148,152,156] restore sp; ret
    c = c + e_addi(0, 31, 0) + e_addi(1, 31, 16) + e_movr(2, 9) + e_movz(8, 221) + e_svc()  // [164..180] .child: execve("/bin/sh", argv, envp)
    c = c + e_movz(0, 127) + e_movz(8, 93) + e_svc()        // [184,188,192] execve failed -> exit(127)
    emit c
}

func emitTry(target, opOff) {
    let c = sbNew()
    c = sbAppend(c, e_movz(0, target % 65536) + e_movk16(0, 32512 + target / 65536))
    c = sbAppend(c, e_movz(9, (opOff + 67108864) % 65536) + e_movk16(9, 32512 + (opOff + 67108864) / 65536))
    c = sbAppend(c, e_ldr0(10, 9) + e_movz(11, 5) + e_lslv(11, 10, 11))
    c = sbAppend(c, e_addr(11, 9, 11) + e_addi(11, 11, 8))
    c = sbAppend(c, e_str0(0, 11) + e_str8(20, 11, 1))
    c = sbAppend(c, e_str8(19, 11, 2) + e_addi(14, 31, 0) + e_str8(14, 11, 3))
    c = sbAppend(c, e_addi(10, 10, 1) + e_str0(10, 9))
    emit sbToString(c)
}
func emitEndTry(opOff) {
    let c = sbNew()
    c = sbAppend(c, e_movz(9, (opOff + 67108864) % 65536) + e_movk16(9, 32512 + (opOff + 67108864) / 65536))
    c = sbAppend(c, e_ldr0(10, 9) + e_cbz(10, 12))
    c = sbAppend(c, e_subi(10, 10, 1) + e_str0(10, 9))
    emit sbToString(c)
}
func emitThrow(opOff) {
    let c = sbNew()
    c = sbAppend(c, c_pop0() + e_movr(12, 0))
    c = sbAppend(c, e_movz(9, (opOff + 67108864) % 65536) + e_movk16(9, 32512 + (opOff + 67108864) / 65536))
    c = sbAppend(c, e_ldr0(10, 9) + e_cbz(10, 64))
    c = sbAppend(c, e_subi(10, 10, 1) + e_str0(10, 9))
    c = sbAppend(c, e_movz(11, 5) + e_lslv(11, 10, 11))
    c = sbAppend(c, e_addr(11, 9, 11) + e_addi(11, 11, 8))
    c = sbAppend(c, e_ldr0(13, 11) + e_ldr8(20, 11, 1))
    c = sbAppend(c, e_ldr8(19, 11, 2) + e_ldr8(14, 11, 3) + e_addi(31, 14, 0))
    c = sbAppend(c, e_movr(0, 12) + c_push() + e_br(13))
    c = sbAppend(c, e_movz(0, 1) + e_movz(8, 93) + e_svc())
    emit sbToString(c)
}

// ── IR helpers ───────────────────────────────────────────────────────────────
func opcode(ln) {                       // first token of an IR line
    let p = indexOf(ln, " ")
    if p < 0 { emit ln }
    emit substring(ln, 0, toInt(p))
}
func operand(ln) {                      // text after the first space
    let p = indexOf(ln, " ")
    if p < 0 { emit "" }
    emit substring(ln, toInt(p) + 1, len(ln))
}
func isStrPush(ln) {                     // PUSH "..."
    if startsWith(ln, "PUSH \"") { emit "1" }
    emit "0"
}
// Decode escape-encoded string back to raw bytes (mirrors linux_x86/elf.k's
// decodeStr). The IR preserves escapes as 2-char text (\n, \t, \\, \", \r);
// decode to real bytes at emit time. Control bytes via fromCharCode so this
// source contains no bare 1-byte escape literals (the seed compiles cleanly).
func decodeStr(s) {
    let nl = fromCharCode("10")
    let tab = fromCharCode("9")
    let cr = fromCharCode("13")
    let bs = fromCharCode("92")
    let dq = fromCharCode("34")
    let out = sbNew()
    let i = 0
    while i < len(s) {
        if s[i] == "\\" && i + 1 < len(s) {
            let c = s[i + 1]
            if c == "n" { out = sbAppend(out, nl) }
            else if c == "t" { out = sbAppend(out, tab) }
            else if c == "r" { out = sbAppend(out, cr) }
            else if c == "\\" { out = sbAppend(out, bs) }
            else if c == "\"" { out = sbAppend(out, dq) }
            else if c == "0" { }  // skip null escape (would terminate string)
            else { out = sbAppend(out, c) }
            i += 2
        } else {
            out = sbAppend(out, s[i])
            i += 1
        }
    }
    emit sbToString(out)
}
// PUSH "..." -> the literal's RAW BYTES (escapes decoded). Used for byte-count,
// offset calc, and data emission alike — all must agree, so decoding lives here.
func quoted(ln) {
    let q1 = indexOf(ln, "\"")
    emit decodeStr(substring(ln, toInt(q1) + 1, len(ln) - 1))
}
// "FUNC add 2" -> "add" ; "CALL add 2" -> "add"
func headName(ln) {
    let rest = operand(ln)
    let p = indexOf(rest, " ")
    if p < 0 { emit rest }
    emit substring(rest, 0, toInt(p))
}
// "FUNC add 2" -> "2"
func funcArgc(ln) {
    let rest = operand(ln)
    let p = indexOf(rest, " ")
    if p < 0 { emit "0" }
    emit substring(rest, toInt(p) + 1, len(rest))
}
// count PARAM+LOCAL slots of the function starting at line fStart.
func countLocals(ir, fStart, globalTab, isMain) {
    let n = toInt(lineCount(ir))
    let i = fStart + 1
    let c = 0
    let seen = ""
    let declared = ""
    while i < n {
        let ln = getLine(ir, i)
        let op = opcode(ln)
        if op == "FUNC" { emit c + "" }
        if op == "END"  { emit c + "" }
        if op == "PARAM" || op == "LOCAL" || op == "LOAD" || op == "STORE" {
            let nm = operand(ln)
            if op == "PARAM" || op == "LOCAL" { declared = declared + "\n" + nm + " " }
            let add = "1"
            if isMain == "0" && (op == "LOAD" || op == "STORE") && tabHas(globalTab, nm) == "1" && indexOf(declared, "\n" + nm + " ") < 0 { add = "0" }
            if add == "1" && indexOf(seen, "\n" + nm + " ") < 0 {
                seen = seen + "\n" + nm + " "
                c = c + 1
            }
        }
        i = i + 1
    }
    emit c + ""
}
// slot index of `name` within the function at fStart (PARAM then LOCAL, in order).
func localSlotIn(ir, fStart, name) {
    let n = toInt(lineCount(ir))
    let i = fStart + 1
    let slot = 0
    while i < n {
        let ln = getLine(ir, i)
        let op = opcode(ln)
        if op == "FUNC" { emit "0" }
        if op == "END"  { emit "0" }
        if op == "PARAM" { if operand(ln) == name { emit slot + "" }  slot = slot + 1 }
        if op == "LOCAL" { if operand(ln) == name { emit slot + "" }  slot = slot + 1 }
        i = i + 1
    }
    emit "0"
}
// byte size of IR line i, WITH function context (FUNC=prologue, RETURN/END=epilogue).
func opBytes(ir, i) {
    let ln = getLine(ir, i)
    let op = opcode(ln)
    if op == "FUNC"   { emit (5 + 3 * toInt(funcArgc(ln))) * 4 + "" }   // prologue
    if op == "PARAM"  { emit "0" }
    if op == "LOCAL"  { emit "0" }
    if op == "RETURN" { emit "20" }                                    // epilogue
    if op == "END"    { emit "32" }                                    // push default ret 0 (do/no-value fns), then epilogue
    if op == "TRY"    { emit "64" }
    if op == "ENDTRY" { emit "24" }
    if op == "THROW"  { emit "100" }
    if op == "CALL" {                                                  // bl, or inlined bitwise builtin
        let cn = headName(ln)
        if cn == "bitAnd" { emit "52" }
        if cn == "bitOr"  { emit "52" }
        if cn == "bitXor" { emit "52" }
        if cn == "bitNot" { emit "24" }
        if cn == "shl"    { emit "52" }
        if cn == "shr"    { emit "52" }
        if cn == "repeat" { emit "40" }
        if cn == "hex" { emit "24" }
        if cn == "rawAlloc"     { emit "20" }
        if cn == "rawFree"      { emit "20" }
        if cn == "rawRealloc"   { emit "28" }
        if cn == "rawReadQword" { emit "32" }
        if cn == "rawWriteQword" { emit "40" }
        if cn == "rawReadByte"  { emit "32" }
        if cn == "rawReadWord"  { emit "28" }
        if cn == "rawWriteWord" { emit "36" }
        if cn == "writeBytes"   { emit "28" }
        if cn == "ptrAdd"       { emit "40" }
        if cn == "ptrToInt"     { emit "20" }
        if cn == "intToPtr"     { emit "20" }
        if cn == "ptrEq"        { emit "32" }
        if cn == "ioctl" || cn == "fdReadN" { emit "36" }
        emit "4"
    }
    emit toInt(opSize(ln)) + ""
}
// Context-aware size: top-level lets live in __main__'s frame and are shared
// with other functions via GB+88, so their LOAD/STORE sequences are 24 bytes.
func opBytesScoped(ir, i, scope, globalTab, declared) {
    let ln = getLine(ir, i)
    let op = opcode(ln)
    if op == "FUNC" {
        let extra = 0
        if headName(ln) == "__main__" { extra = 12 }
        emit ((5 + 3 * toInt(funcArgc(ln))) * 4 + extra) + ""
    }
    if op == "LOAD" || op == "STORE" {
        if scope != "__main__" && tabHas(globalTab, operand(ln)) == "1" && indexOf(declared, "\n" + operand(ln) + " ") < 0 { emit "24" }
    }
    emit opBytes(ir, i)
}
func tabHas(tab, name) {
    if indexOf(tab, "\n" + name + " ") >= 0 { emit "1" }
    emit "0"
}
// Look up `name` in a "\nNAME VAL\nNAME VAL..." table. Uses indexOf (NOT getLine)
// so it does NOT touch / evict the kr_getline pointer cache — critical: these
// lookups interleave with the main codegen IR walk, and a single-entry getLine
// cache would be thrashed if every jump/load did a getLine on a SECOND string,
// re-introducing O(n^2). indexOf is a plain char-scan over the (small) table.
// Returns the VAL string (digits after "NAME ") or "0" if absent.
func tabLookup(tab, name) {
    let p = toInt(indexOf(tab, "\n" + name + " "))
    if p < 0 { emit "0" }
    let vs = p + len(name) + 2                 // skip "\n" + name + " "
    let n = len(tab)
    let e = vs
    let stop = 0
    while e < n && stop == 0 {
        if tab[e] == "\n" { stop = 1 }
        else { e = e + 1 }
    }
    emit substring(tab, vs, e)
}
// absolute byte offset of LABEL/FUNC `name`, via the precomputed offset table.
func labelAbsOffset(tab, name) { emit tabLookup(tab, name) }
func funcVaddrOf(tab, name) { emit tabLookup(tab, name) }
// per-function local-slot table "\nNAME SLOT..." (params then locals, in order).
// Built ONCE per function at its FUNC line (forward walk, getLine-cache friendly);
// STORE/LOAD then resolve slots via tabLookup (indexOf, no getLine) instead of
// re-walking the IR per access (localSlotIn was O(funcLen) getLine per LOAD/STORE).
func buildSlots(ir, fStart, globalTab, isMain) {
    let i = fStart + 1
    let slot = 0
    let out = sbNew()
    let seen = ""
    let declared = ""
    let keep = 1
    while keep == 1 {
        let ln = getLine(ir, i)
        let op = opcode(ln)
        if op == "FUNC" { keep = 0 }
        else if op == "END" { keep = 0 }
        else if op == "PARAM" || op == "LOCAL" || op == "LOAD" || op == "STORE" {
            let nm = operand(ln)
            if op == "PARAM" || op == "LOCAL" { declared = declared + "\n" + nm + " " }
            let add = "1"
            if isMain == "0" && (op == "LOAD" || op == "STORE") && tabHas(globalTab, nm) == "1" && indexOf(declared, "\n" + nm + " ") < 0 { add = "0" }
            if add == "1" && indexOf(seen, "\n" + nm + " ") < 0 {
                out = sbAppend(out, "\n" + nm + " " + (slot + ""))
                seen = seen + "\n" + nm + " "
                slot = slot + 1
            }
        }
        i = i + 1
    }
    emit sbToString(out)
}
func emitFLoad1() {
    emit e_movzHi(9, 32512) + e_cmp(0, 9) + e_bge(12) + e_scvtf(0, 0) + e_ret() + e_ldrd(0, 0) + e_ret()
}
func emitFLoad2() {
    emit e_movzHi(9, 32512) + e_cmp(1, 9) + e_bge(12) + e_scvtf(1, 1) + e_ret() + e_ldrd(1, 1) + e_ret()
}
func emitFBox(allocOff, thisOff) {
    emit e_movr(24, 30) + e_movz(0, 8) + e_bl(allocOff - (thisOff + 8))
        + e_strd(0, 0) + e_movr(30, 24) + e_ret()
}
// x0=value, x1=precision. Produces a fixed decimal string in a 48-byte buffer.
func emitFFormat(allocOff, thisOff) {
    let s = e_movr(25, 30) + e_movzHi(12, 32512) + e_cmp(0, 12) + e_bge(12)
    s = s + e_scvtf(0, 0) + e_b(8) + e_ldrd(0, 0)
    s = s + e_fcmp0(0) + e_cset(13, 5) + e_fabs(0, 0)
    s = s + e_movr(14, 1) + e_movz(3, 1) + e_movr(4, 1)
    s = s + e_cbz(4, 20) + e_movz(5, 10) + e_mul(3, 3, 5) + e_subi(4, 4, 1) + e_b(0 - 16)
    s = s + e_movr(15, 3) + e_scvtf(1, 3) + e_fmul(0, 0, 1)
    s = s + e_movz(2, 1) + e_scvtf(2, 2) + e_movz(3, 2) + e_scvtf(3, 3) + e_fdiv(2, 2, 3)
    s = s + e_fadd(0, 0, 2) + e_frintm(0, 0) + e_fcvtzs(16, 0)
    s = s + e_movz(0, 48) + e_bl(allocOff - (thisOff + 120))
    s = s + e_addi(6, 0, 47) + e_movz(7, 0) + e_strb(7, 6) + e_subi(6, 6, 1) + e_movr(8, 14)
    s = s + e_cbz(8, 40) + e_movz(5, 10) + e_udiv(9, 16, 5) + e_msub(10, 9, 5, 16)
    s = s + e_addi(10, 10, 48) + e_strb(10, 6) + e_subi(6, 6, 1) + e_movr(16, 9) + e_subi(8, 8, 1) + e_b(0 - 36)
    s = s + e_cbz(14, 16) + e_movz(7, 46) + e_strb(7, 6) + e_subi(6, 6, 1)
    s = s + e_movz(5, 10) + e_udiv(9, 16, 5) + e_msub(10, 9, 5, 16) + e_addi(10, 10, 48)
    s = s + e_strb(10, 6) + e_subi(6, 6, 1) + e_movr(16, 9) + e_cbnz(16, 0 - 24)
    s = s + e_cbz(13, 16) + e_movz(7, 45) + e_strb(7, 6) + e_subi(6, 6, 1)
    s = s + e_addi(0, 6, 1) + e_movr(30, 25) + e_ret()
    emit s
}

// kr_readline(x0=prompt or 0) -> fresh line without LF. Reads one byte at a
// time so successive calls cannot consume and lose each other's input.
func emitReadline(allocOff, thisOff) {
    let c = e_movr(24, 30) + e_movr(10, 0) + e_cbz(10, 40)
    c = c + e_movz(1, 0) + e_ldrbO(2, 10, 1) + e_cbz(2, 12)
    c = c + e_addi(1, 1, 1) + e_b(0 - 12)
    c = c + e_movr(1, 10) + e_movr(0, 1) + e_movz(8, 64) + e_svc()
    c = c + e_movz(0, 4097) + e_bl(allocOff - (thisOff + 52))
    c = c + e_movr(11, 0) + e_movr(12, 0) + e_movz(13, 4096)
    c = c + e_movz(0, 0) + e_movr(1, 12) + e_movz(2, 1) + e_movz(8, 63) + e_svc()
    c = c + e_cmpi0(0) + e_blt(32) + e_cbz(0, 28)
    c = c + e_ldrb0(2, 12) + e_subi(2, 2, 10) + e_cbz(2, 16)
    c = c + e_addi(12, 12, 1) + e_subi(13, 13, 1) + e_cbnz(13, 0 - 52)
    c = c + e_strb(31, 12) + e_movr(0, 11) + e_movr(30, 24) + e_ret()
    emit c
}

func emitIsSpace() {
    let c = e_ldrb0(1, 0) + e_subi(2, 1, 9) + e_movz(3, 4)
    c = c + e_cmp(2, 3) + e_cset(2, 8) + e_movz(4, 32)
    c = c + e_cmp(1, 4) + e_cset(0, 1) + e_orr(0, 0, 2) + e_ret()
    emit c
}

func emitRandom() {
    let c = e_movr(10, 0) + e_subi(31, 31, 16) + e_str0(31, 31)
    c = c + e_addi(0, 31, 0) + e_movz(1, 16) + e_movz(2, 0)
    c = c + e_movz(8, 278) + e_svc() + e_ldr0(0, 31) + e_addi(31, 31, 16)
    c = c + e_cmpi0(10) + e_ble(16)
    c = c + e_udiv(1, 0, 10) + e_msub(0, 1, 10, 0) + e_ret()
    c = c + e_movz(0, 0) + e_ret()
    emit c
}
func emitTimestamp(strIntOff, thisOff) {
    let c = e_movr(26, 30) + e_subi(31, 31, 16)
    c = c + e_movz(0, 0) + e_addi(1, 31, 0) + e_movz(2, 0)
    c = c + e_movz(8, 113) + e_svc() + e_ldr0(0, 31) + e_addi(31, 31, 16)
    c = c + e_bl(strIntOff - (thisOff + 36)) + e_movr(30, 26) + e_ret()
    emit c
}

// ── Linux syscall helpers (slots 58..82, 512 bytes each) ─────────────────────
// The caller pops arguments into x0..x6, then BLs the matching slot. Helpers
// return the raw Linux result in x0 (negative errno on failure), exactly like
// the x86 backend. x19/x20/x21/x22 are VM state and are never changed here.
func emitFdReadN() {
    let c = e_movz(8, 63) + e_svc() + e_ret()                  // read(fd,buf,n)
    emit c
}
func emitFdRead(allocOff, thisOff) {
    let c = e_movr(24, 30) + e_movr(10, 1) + e_movr(11, 0)    // lr, n, fd
    c = c + e_addi(0, 10, 1) + e_bl(allocOff - (thisOff + 16)) // alloc(n+1)
    c = c + e_movr(12, 0) + e_movr(0, 11) + e_movr(1, 12)
    c = c + e_movr(2, 10) + e_movz(8, 63) + e_svc()
    c = c + e_cmpi0(0) + e_bge(8) + e_movz(0, 0)             // clamp negative nread
    c = c + e_addr(1, 12, 0) + e_strb(31, 1) + e_movr(0, 12)
    c = c + e_movr(30, 24) + e_ret()
    emit c
}
func emitFdWrite() {
    let c = e_movz(8, 64) + e_svc() + e_ret()                  // write(fd,buf,len)
    emit c
}
func emitFdClose() {
    let c = e_movz(8, 57) + e_svc() + e_ret()                  // close(fd)
    emit c
}
func emitFdSetNonblock() {
    let c = e_movz(1, 4) + e_movz(2, 2048) + e_movz(8, 25)
    c = c + e_svc() + e_ret()                                  // fcntl(F_SETFL,O_NONBLOCK)
    emit c
}
func emitIoctl() {
    let c = e_movz(8, 29) + e_svc() + e_ret()                  // ioctl(fd,req,argp)
    emit c
}
func emitMemfdCreate() {
    let c = e_movr(10, 0) + e_subi(31, 31, 16) + e_strb(31, 31)
    c = c + e_addi(0, 31, 0) + e_movz(1, 0) + e_movz(8, 279)
    c = c + e_svc() + e_movr(11, 0) + e_addi(31, 31, 16)
    c = c + e_movr(0, 11) + e_movr(1, 10) + e_movz(8, 46)
    c = c + e_svc() + e_movr(0, 11) + e_ret()                  // return original fd
    emit c
}
func emitMmapShared() {
    let c = e_movr(4, 0) + e_movz(0, 0) + e_movz(2, 3)
    c = c + e_movz(3, 1) + e_movz(5, 0) + e_movz(8, 222)
    c = c + e_svc() + e_ret()                                  // mmap(0,size,RW,SHARED,fd,0)
    emit c
}
func emitPtyMaster() {
    let c = e_movr(10, 0) + e_movn(0, 99) + e_movr(1, 10)
    c = c + e_movz(2, 258) + e_movz(3, 0) + e_movz(8, 56)
    c = c + e_svc() + e_movr(11, 0) + e_subi(31, 31, 16)
    c = c + e_str0(31, 31) + e_movr(0, 11) + c_loadHalves(1, 21553, 16388)
    c = c + e_addi(2, 31, 0) + e_movz(8, 29) + e_svc()
    c = c + e_addi(31, 31, 16) + e_movr(0, 11) + e_ret()
    emit c
}
func emitPtySlaveName(strIntOff, plusOff, thisOff) {
    let c = e_movr(26, 30) + e_movr(10, 0) + e_subi(31, 31, 32)
    c = c + c_loadHalves(1, 21552, 32772) + e_addi(2, 31, 0) + e_movz(8, 29)
    c = c + e_svc() + e_ldr0(0, 31) + e_bl(strIntOff - (thisOff + 36))
    c = c + e_str8(0, 31, 3) + e_addi(0, 31, 8)
    c = c + e_movz(1, 47) + e_strbO(1, 0, 0) + e_movz(1, 100)
    c = c + e_strbO(1, 0, 1) + e_movz(1, 101) + e_strbO(1, 0, 2)
    c = c + e_movz(1, 118) + e_strbO(1, 0, 3) + e_movz(1, 47)
    c = c + e_strbO(1, 0, 4) + e_movz(1, 112) + e_strbO(1, 0, 5)
    c = c + e_movz(1, 116) + e_strbO(1, 0, 6) + e_movz(1, 115)
    c = c + e_strbO(1, 0, 7) + e_movz(1, 47) + e_strbO(1, 0, 8)
    c = c + e_movz(1, 0) + e_strbO(1, 0, 9)
    c = c + e_ldr8(1, 31, 3) + e_bl(plusOff - (thisOff + 132))
    c = c + e_addi(31, 31, 32) + e_movr(30, 26) + e_ret()
    emit c
}
func emitPtyForkExec(opOff) {
    let c = e_movr(10, 0) + e_movr(11, 1) + e_movz(0, 0)
    c = c + e_movz(1, 0) + e_movz(8, 220)
    c = c + e_svc() + e_cbz(0, 8) + e_ret()                  // parent returns; child at +32
    c = c + e_movz(8, 157) + e_svc()                          // setsid()
    c = c + e_movn(0, 99) + e_movr(1, 10) + e_movz(2, 2)
    c = c + e_movz(3, 0) + e_movz(8, 56) + e_svc()           // openat(slave,O_RDWR)
    c = c + e_movr(12, 0) + e_movr(0, 12) + e_movz(1, 21518)
    c = c + e_movz(2, 0) + e_movz(8, 29) + e_svc()           // TIOCSCTTY
    c = c + e_movr(0, 12) + e_movz(1, 0) + e_movz(2, 0)
    c = c + e_movz(8, 24) + e_svc()                           // dup3(slave,0,0)
    c = c + e_movr(0, 12) + e_movz(1, 1) + e_movz(2, 0)
    c = c + e_movz(8, 24) + e_svc()                           // dup3(slave,1,0)
    c = c + e_movr(0, 12) + e_movz(1, 2) + e_movz(2, 0)
    c = c + e_movz(8, 24) + e_svc()                           // dup3(slave,2,0)
    c = c + e_subi(31, 31, 16) + e_str8(11, 31, 0) + e_str8(31, 31, 1)
    c = c + e_movr(0, 11) + e_addi(1, 31, 0)
    c = c + e_movz(2, opOff % 65536) + e_movk16(2, 32512 + opOff / 65536)
    c = c + e_ldr8(2, 2, 10) + e_movz(8, 221) + e_svc()      // execve(shell,argv,envp)
    c = c + e_movz(0, 127) + e_movz(8, 93) + e_svc()
    emit c
}
func emitPtySetSize() {
    let c = e_movr(10, 0) + e_movr(11, 1) + e_movr(12, 2)
    c = c + e_subi(31, 31, 16) + e_str0(31, 31) + e_str8(31, 31, 1)
    c = c + e_strhO(11, 31, 0) + e_strhO(12, 31, 2)
    c = c + e_movr(0, 10) + e_addi(2, 31, 0) + e_movz(1, 21524)
    c = c + e_movz(8, 29) + e_svc() + e_addi(31, 31, 16) + e_ret()
    emit c
}
func emitSleepUs() {
    let c = e_movr(10, 0) + e_movz(11, 1000) + e_mul(11, 1, 11)
    c = c + e_subi(31, 31, 16) + e_str8(10, 31, 0) + e_str8(11, 31, 1)
    c = c + e_addi(0, 31, 0) + e_movz(1, 0) + e_movz(8, 101)
    c = c + e_svc() + e_addi(31, 31, 16) + e_ret()
    emit c
}
func emitWaitChild() {
    let c = e_movr(10, 0) + e_subi(31, 31, 16) + e_str0(31, 31)
    c = c + e_movr(0, 10) + e_addi(1, 31, 0) + e_movz(2, 1)
    c = c + e_movz(3, 0) + e_movz(8, 260) + e_svc()
    c = c + e_addi(31, 31, 16) + e_ret()
    emit c
}
func emitProcAlive() {
    let c = e_movz(1, 0) + e_movz(8, 129) + e_svc()
    c = c + e_cmpi0(0) + e_cset(0, 1) + e_ret()
    emit c
}
func emitSockMake() {
    let c = e_movz(0, 2) + e_movz(1, 1) + e_movz(2, 0)
    c = c + e_movz(8, 198) + e_svc() + e_ret()
    emit c
}
func emitSockBind() {
    let c = e_movr(10, 0) + e_movr(11, 1) + e_movr(12, 2)
    c = c + e_subi(31, 31, 16) + e_str0(31, 31) + e_str8(31, 31, 1)
    c = c + e_movz(13, 2) + e_strhO(13, 31, 0)
    c = c + e_strbO(11, 31, 2) + e_strbO(12, 31, 3)
    c = c + e_movr(0, 10) + e_addi(1, 31, 0) + e_movz(2, 16)
    c = c + e_movz(8, 200) + e_svc() + e_addi(31, 31, 16) + e_ret()
    emit c
}
func emitSockListen() {
    let c = e_movz(8, 201) + e_svc() + e_ret()
    emit c
}
func emitSockAccept() {
    let c = e_movz(1, 0) + e_movz(2, 0) + e_movz(8, 202)
    c = c + e_svc() + e_ret()
    emit c
}
func emitSockRecv() {
    let c = e_movz(3, 0) + e_movz(4, 0) + e_movz(5, 0)
    c = c + e_movz(8, 207) + e_svc() + e_ret()
    emit c
}
func emitSockSend() {
    let c = e_movz(8, 64) + e_svc() + e_ret()
    emit c
}
func emitSockClose() {
    let c = e_movz(8, 57) + e_svc() + e_ret()
    emit c
}
func emitSockRecvStr(allocOff, thisOff) {
    let c = e_movr(24, 30) + e_movr(10, 0) + e_movz(0, 1)
    c = c + e_movk16(0, 1) + e_bl(allocOff - (thisOff + 16))  // alloc(65537)
    c = c + e_movr(11, 0) + e_movr(0, 10) + e_movr(1, 11)
    c = c + e_movz(2, 0) + e_movk16(2, 1) + e_movz(3, 0)
    c = c + e_movz(4, 0) + e_movz(5, 0) + e_movz(8, 207)
    c = c + e_svc() + e_cmpi0(0) + e_bge(8) + e_movz(0, 0)
    c = c + e_movr(12, 0) + e_strbR(31, 11, 12) + e_movr(0, 11)
    c = c + e_movr(30, 24) + e_ret()
    emit c
}
func emitSockConnect() {
    let c = e_movr(10, 0) + e_movr(11, 1) + e_movr(12, 2)
    c = c + e_movr(13, 3) + e_movr(14, 4) + e_movr(15, 5)
    c = c + e_movr(16, 6) + e_subi(31, 31, 16) + e_str0(31, 31)
    c = c + e_str8(31, 31, 1) + e_movz(9, 2) + e_strhO(9, 31, 0)
    c = c + e_strbO(15, 31, 2) + e_strbO(16, 31, 3)
    c = c + e_strbO(11, 31, 4) + e_strbO(12, 31, 5)
    c = c + e_strbO(13, 31, 6) + e_strbO(14, 31, 7)
    c = c + e_movr(0, 10) + e_addi(1, 31, 0) + e_movz(2, 16)
    c = c + e_movz(8, 203) + e_svc() + e_addi(31, 31, 16) + e_ret()
    emit c
}
func emitSockSendFd() {
    let c = e_movr(10, 0) + e_movr(11, 1) + e_movr(12, 2)
    c = c + e_movr(13, 3) + e_subi(31, 31, 96)
    c = c + e_str8(31, 31, 0) + e_str8(31, 31, 1) + e_str8(31, 31, 2)
    c = c + e_str8(31, 31, 3) + e_str8(31, 31, 4) + e_str8(31, 31, 5)
    c = c + e_str8(31, 31, 6) + e_str8(31, 31, 7) + e_str8(31, 31, 8)
    c = c + e_str8(31, 31, 9) + e_str8(31, 31, 10) + e_str8(31, 31, 11)
    c = c + e_str8(11, 31, 0) + e_str8(12, 31, 1) + e_movz(0, 20)
    c = c + e_str8(0, 31, 2) + e_movz(0, 1) + e_strwO(0, 31, 24)
    c = c + e_strwO(0, 31, 28) + e_strwO(13, 31, 32)
    c = c + e_addi(0, 31, 0) + e_str8(0, 31, 7) + e_movz(0, 1)
    c = c + e_str8(0, 31, 8) + e_addi(0, 31, 16) + e_str8(0, 31, 9)
    c = c + e_movz(0, 20) + e_str8(0, 31, 10)
    c = c + e_movr(0, 10) + e_addi(1, 31, 40) + e_movz(2, 0)
    c = c + e_movz(8, 211) + e_svc() + e_addi(31, 31, 96) + e_ret()
    emit c
}

// Fixed helper-slot map. Keep syscallBuiltinArgs in the same order as the
// slot map; callers use both to pop arguments and size the emitted BL sequence.
func syscallBuiltinBase(name) {
    let p = indexOf(name, " ")
    if p >= 0 { emit substring(name, 0, p) }
    emit name
}
func syscallBuiltinSlot(name) {
    let key = syscallBuiltinBase(name)
    if key == "fdReadN" { emit "58" }
    if key == "fdRead" { emit "59" }
    if key == "fdWrite" { emit "60" }
    if key == "fdClose" { emit "61" }
    if key == "fdSetNonblock" { emit "62" }
    if key == "ioctl" { emit "63" }
    if key == "memfdCreate" { emit "64" }
    if key == "mmapShared" { emit "65" }
    if key == "ptyMaster" { emit "66" }
    if key == "ptySlaveName" { emit "67" }
    if key == "ptyForkExec" { emit "68" }
    if key == "ptySetSize" { emit "69" }
    if key == "sleepUs" { emit "70" }
    if key == "waitChild" { emit "71" }
    if key == "procAlive" { emit "72" }
    if key == "sockMake" { emit "73" }
    if key == "sockBind" { emit "74" }
    if key == "sockListen" { emit "75" }
    if key == "sockAccept" { emit "76" }
    if key == "sockRecv" { emit "77" }
    if key == "sockSend" { emit "78" }
    if key == "sockClose" { emit "79" }
    if key == "sockRecvStr" { emit "80" }
    if key == "sockConnect" { emit "81" }
    if key == "sockSendFd" { emit "82" }
    emit "0"
}
func syscallBuiltinArgs(name) {
    let key = syscallBuiltinBase(name)
    if key == "fdReadN" { emit "3" }
    if key == "fdRead" { emit "2" }
    if key == "fdWrite" { emit "3" }
    if key == "fdClose" { emit "1" }
    if key == "fdSetNonblock" { emit "1" }
    if key == "ioctl" { emit "3" }
    if key == "memfdCreate" { emit "1" }
    if key == "mmapShared" { emit "2" }
    if key == "ptyMaster" { emit "1" }
    if key == "ptySlaveName" { emit "1" }
    if key == "ptyForkExec" { emit "2" }
    if key == "ptySetSize" { emit "3" }
    if key == "sleepUs" { emit "2" }
    if key == "waitChild" { emit "1" }
    if key == "procAlive" { emit "1" }
    if key == "sockMake" { emit "0" }
    if key == "sockBind" { emit "3" }
    if key == "sockListen" { emit "2" }
    if key == "sockAccept" { emit "1" }
    if key == "sockRecv" { emit "3" }
    if key == "sockSend" { emit "3" }
    if key == "sockClose" { emit "1" }
    if key == "sockRecvStr" { emit "1" }
    if key == "sockConnect" { emit "7" }
    if key == "sockSendFd" { emit "4" }
    emit "0"
}

// byte size of a non-structural op (body of a function).
func opSize(ln) {
    let op = opcode(ln)
    if op == "PUSH" {
        if isStrPush(ln) == "1" { emit "16" }
        if indexOf(operand(ln), ".") >= 0 { emit "60" }
        emit immBytes(operand(ln))
    }
    if op == "FUNCPTR" { emit 16 }
    if op == "STORE"   { emit 12 }
    if op == "LOAD"    { emit 12 }
    if op == "ADD"     { emit 28 }
    if op == "CAT"     { emit 28 }
    if op == "SUB"     { emit 52 }
    if op == "MUL"     { emit 52 }
    if op == "DIV"     { emit 52 }
    if op == "MOD"     { emit 56 }
    if op == "POP"     { emit 4 }
    if op == "LABEL"     { emit 0 }
    if op == "JUMP"      { emit 4 }
    if op == "JUMPIFNOT" { emit 16 }   // pop + bl istruthy + cbz (was naive cbz)
    if op == "JUMPIF"    { emit 16 }   // pop + bl istruthy + cbnz (|| short-circuit)
    if op == "NOT"       { emit 28 }   // pop + bl istruthy + (x0 ^= 1) + push
    if op == "NEG"       { emit 48 }   // polymorphic int/boxed-f64 negation
    if op == "LT" || op == "GT" || op == "LTE" || op == "GTE" { emit 36 }   // bl kr_cmp + cmpi0 + cset
    if op == "EQ"  { emit 28 }     // polymorphic kr_eq (numeric OR strcmp)
    if op == "NEQ" { emit 36 }     // kr_eq + invert
    if op == "INDEX" { emit 40 }   // coerce index; fresh one-char string
    if op == "SETFIELD" { emit 36 }  // p.x=v: pop val/env, name imm -> kr_setfield
    if op == "GETFIELD" { emit 28 }  // p.x: pop env, name imm -> kr_getfield
    if op == "STRUCTNEW" { emit 12 } // empty struct/env sentinel
    if op == "BUILTIN" {
        let b = operand(ln)
        if startsWith(b, "kp") { emit 24 }   // pop + dispatch/print + push 0
        if startsWith(b, "gcShadowCount") { emit 12 }
        if startsWith(b, "gcShadowPush") { emit 16 }
        if startsWith(b, "gcShadowPop") { emit 16 }
        if startsWith(b, "charCode") { emit 20 }
        if startsWith(b, "charAt") { emit 40 }
        if startsWith(b, "isSpace") { emit 20 }
        if startsWith(b, "length") { emit 20 }  // collection count -> kr_count (BEFORE "len" to avoid strlen match)
        if startsWith(b, "len") { emit 56 }
        if startsWith(b, "toStr") { emit 32 }
        if startsWith(b, "toInt") { emit 20 }
        if startsWith(b, "fromCharCode") { emit 40 }
        if startsWith(b, "substring") { emit 80 }
        if startsWith(b, "isTruthy") { emit 20 }
        if startsWith(b, "min") { emit 56 }   // coerce both, compare, select
        if startsWith(b, "max") { emit 56 }
        if startsWith(b, "hex") { emit 24 }   // atoi + kr_hex
        if startsWith(b, "bin") { emit 24 }   // atoi + kr_bin
        if startsWith(b, "padLeft")  { emit 88 }  // coerce width; stringify int s
        if startsWith(b, "padRight") { emit 88 }
        if startsWith(b, "toUpper") { emit 20 }   // pop0 + bl + push
        if startsWith(b, "toLower") { emit 20 }
        if startsWith(b, "reverse") { emit 20 }
        if startsWith(b, "strReverse") { emit 20 }
        if startsWith(b, "startsWith") { emit 28 }  // pop0+pop1 + bl + push
        if startsWith(b, "endsWith")   { emit 28 }
        if startsWith(b, "repeat")     { emit 40 }   // coerce repeat count
        if startsWith(b, "contains")   { emit 28 }
        if startsWith(b, "indexOf")    { emit 28 }
        if startsWith(b, "trim")       { emit 20 }  // 1-arg: pop0 + bl + push
        if startsWith(b, "split")      { emit 32 }  // 2-arg (list, idx); idx coerced via atoi
        if startsWith(b, "lineCount")  { emit 20 }  // 1-arg: pop + bl kr_linecount + push
        if startsWith(b, "getLine")    { emit 32 }  // 2-arg (s, idx); idx via atoi
        if startsWith(b, "count")      { emit 20 }  // 1-arg (list)
        if startsWith(b, "abs")        { emit 32 }  // atoi + signed abs
        if startsWith(b, "pow")        { emit 56 }  // coerce base/exp + kr_pow
        if startsWith(b, "range 1")    { emit 28 }  // atoi end; start=0
        if startsWith(b, "range 2")    { emit 56 }  // coerce start/end
        if startsWith(b, "sbNew")      { emit 12 }  // 0-arg: bl + push
        if startsWith(b, "sbAppend")   { emit 52 }  // stringify integer s; append
        if startsWith(b, "sbToString") { emit 20 }  // 1-arg (handle)
        if startsWith(b, "exit")       { emit 28 }  // pop + atoi + movz x8,93 + svc + push
        if startsWith(b, "bufStr ") { emit 12 }
        if startsWith(b, "bufGetDword ") { emit 24 }
        if startsWith(b, "bufGetWord ") { emit 24 }
        if startsWith(b, "bufGetQword ") { emit 24 }
        if startsWith(b, "bufSetDword ") { emit 28 }
        if startsWith(b, "bufSetWord ") { emit 28 }
        if startsWith(b, "handleOut") { emit 16 }
        if startsWith(b, "handleGet") { emit 20 }
        if startsWith(b, "handleInt") { emit 20 }
        if startsWith(b, "toHandle") { emit 20 }
        if startsWith(b, "ptrDeref") { emit 20 }
        if startsWith(b, "ptrIndex") { emit 48 }
        if startsWith(b, "bufNew ")    { emit 20 }  // alloc(size): pop+bl alloc+push
        if startsWith(b, "bufSetQwordAt ") { emit 44 } // [buf+off]=val (64-bit)
        if startsWith(b, "bufSetWordAt ")  { emit 44 } // [buf+off]=val (16-bit)
        if startsWith(b, "bufSetDwordAt ") { emit 44 } // [buf+off]=val (32-bit)
        if startsWith(b, "bufSetByte ") { emit 36 } // [buf+off]=val: 3 pops + strb + push
        if startsWith(b, "bufGetQwordAt ") { emit 32 } // 64-bit load via addr+ldr
        if startsWith(b, "bufGetByte ") { emit 28 } // buf[off]: 2 pops + ldrb + push
        if startsWith(b, "bufGetWordAt ") { emit 28 }  // u16 LE: 2 pops + ldrh + push
        if startsWith(b, "bufGetDwordAt ") { emit 28 } // u32 LE: 2 pops + ldrw + push
        if startsWith(b, "bufGetWordAtBE ") { emit 32 }
        if startsWith(b, "bufGetDwordAtBE ") { emit 32 }
        if startsWith(b, "bufGetQwordAtBE ") { emit 36 }
        if startsWith(b, "unixConnect") { emit 128 }   // socket+connect(AF_UNIX) inline
        if startsWith(b, "readLine 1") { emit 20 }  // prompt + line
        if startsWith(b, "readLine 0") { emit 16 }  // line only
        if startsWith(b, "input") { emit 16 }
        if startsWith(b, "readFile")   { emit 20 }  // 1-arg (path)
        if startsWith(b, "writeFile")  { emit 28 }  // 2-arg (path, content)
        if startsWith(b, "argCount")   { emit 12 }  // 0-arg: bl kr_argcount + push (BEFORE "arg")
        if startsWith(b, "arg")        { emit 24 }  // 1-arg: pop + atoi + bl kr_arg + push
        if startsWith(b, "printErr")   { emit 24 }  // pop + print + push 0
        if startsWith(b, "isDigit")    { emit 20 }  // 1-arg: pop + bl kr_isdigit + push
        if startsWith(b, "isAlpha")    { emit 52 }  // first byte A-Z/a-z
        if startsWith(b, "parseInt")   { emit 20 }  // alias for toInt
        if startsWith(b, "kr_str")     { emit 32 }  // internal alias for toStr
        if startsWith(b, "gcLiveCount") { emit 12 } // alias for gcWalkAllocs
        if startsWith(b, "gcMark") { emit 12 }
        if startsWith(b, "gcSweep") { emit 12 }
        if startsWith(b, "gcReset") { emit 12 }
        if startsWith(b, "gcCheckpoint") { emit 12 }
        if startsWith(b, "gcRestore") { emit 20 }
        if startsWith(b, "gcSlabCount") { emit 12 }
        if startsWith(b, "gcSlabBytes") { emit 12 }
        if startsWith(b, "gcSetThreshold") { emit 20 }
        if startsWith(b, "gcSetLimit")   { emit 36 }  // atoi + store gcGlobals[limit] + push 0
        if startsWith(b, "replace")    { emit 36 }  // 3-arg: pop x2/x1/x0 + bl kr_replace + push
        if startsWith(b, "random") { emit 20 }
        if startsWith(b, "timestamp") { emit 12 }
        if startsWith(b, "environ")    { emit 20 }  // 1-arg: pop + bl kr_environ + push
        if startsWith(b, "readProc")   { emit 20 }  // 1-arg: pop + bl kr_readproc + push
        if startsWith(b, "ptrToInt")   { emit 20 }  // raw pointer -> decimal string
        if startsWith(b, "intToPtr")   { emit 20 }  // decimal string/int -> raw pointer
        if startsWith(b, "callPtr")    { emit 28 }  // load fp, blr, replace fp slot with callee result
        if startsWith(b, "shellRun")   { emit 20 }  // 1-arg: pop + bl kr_shellrun + push
        if startsWith(b, "exec ")      { emit 20 }  // 1-arg: pop + bl kr_exec + push
        if startsWith(b, "gcCollect")    { emit 12 }  // no-op (bump allocator): push 0
        if startsWith(b, "gcAllocCount") { emit 20 }  // load gcGlobals[count]
        if startsWith(b, "gcAllocated")  { emit 20 }  // load gcGlobals[bytes]
        if startsWith(b, "gcLimit")      { emit 20 }  // load gcGlobals[limit]
        if startsWith(b, "gcFreelistCount") { emit 40 }  // walk freelist chain
        if startsWith(b, "gcWalkAllocs") { emit 12 }  // stub: push 0
        if startsWith(b, "pause") { emit 16 }
        if startsWith(b, "mfence") { emit 20 }
        if startsWith(b, "lfence") { emit 20 }
        if startsWith(b, "sfence") { emit 20 }
        if startsWith(b, "rdtsc")        { emit 24 }  // mrs cntvct_el0 + mask low 30 bits + push
        if startsWith(b, "structNew")  { emit 12 }  // push 0 (empty env)
        if startsWith(b, "envNew")     { emit 12 }
        if startsWith(b, "setField")   { emit 36 }  // 3-arg (env, name, val) -> kr_setfield
        if startsWith(b, "envSet")     { emit 36 }
        if startsWith(b, "getField")   { emit 28 }  // 2-arg (env, name) -> kr_getfield
        if startsWith(b, "envGet")     { emit 28 }
        if startsWith(b, "hasField")   { emit 28 }  // 2-arg -> kr_hasfield (1/0)
        if startsWith(b, "structFields") { emit 20 }  // 1-arg -> kr_structfields
        if startsWith(b, "fadd") || startsWith(b, "fsub") || startsWith(b, "fmul") || startsWith(b, "fdiv") { emit 40 }
        if startsWith(b, "feq") || startsWith(b, "flt") || startsWith(b, "fgt") { emit 48 }
        if startsWith(b, "fsqrt") || startsWith(b, "ffloor") || startsWith(b, "fceil") { emit 28 }
        if startsWith(b, "fround") { emit 72 }
        if startsWith(b, "intToFloat") || startsWith(b, "floatToInt") { emit 24 }
        if startsWith(b, "fformat") { emit 28 }
        let sysSlot = toInt(syscallBuiltinSlot(b))
        if sysSlot > 0 { emit (toInt(syscallBuiltinArgs(b)) * 8 + 12) + "" }
        emit 0
    }
    emit 0
}

just run {
    let inFile  = arg("0")
    let outFile = arg("1")
    let ir = readFile(inFile)
    let nlines = toInt(lineCount(ir))

    let HDR = 120
    let START = 76                       // _start: argc/argv/envp capture (11) + x20/x22 (4) + bl + 3 exit = 19 instr

    // Top-level lets are stored in __main__'s frame. Build their slot table once
    // so other functions can share them through the saved main-frame pointer.
    let mainStart = 0 - 1
    i = 0
    while i < nlines {
        let ml = getLine(ir, i)
        if opcode(ml) == "FUNC" && headName(ml) == "__main__" { mainStart = i }
        i = i + 1
    }
    let globalTab = ""
    if mainStart >= 0 { globalTab = buildSlots(ir, mainStart, "", "1") }

    // ONE O(n) pass: total code size + precomputed LABEL/FUNC offset tables
    // ("name off\n" per entry). Replaces the old per-jump full-IR re-walk in
    // labelAbsOffset/funcVaddrOf (J jumps * n lines * opBytes = O(n^2), which
    // blew up compile time + RAM on big self-host IR). aoff mirrors the old
    // off seed: HDR(120) + _start(32) = 152, advanced by opBytes per line.
    let codeSize = 0
    let labelTabB = sbNew()
    let funcTabB = sbNew()
    let aoff = HDR + START               // first code byte after HDR + _start (was 152 @ START=32)
    let scope = ""
    let declared = ""
    let i = 0
    while i < nlines {
        let ln0 = getLine(ir, i)
        let op0 = opcode(ln0)
        if op0 == "FUNC" { scope = headName(ln0)  declared = "" }
        if op0 == "PARAM" || op0 == "LOCAL" { declared = declared + "\n" + operand(ln0) + " " }
        if op0 == "LABEL" { labelTabB = sbAppend(labelTabB, "\n" + scope + ":" + operand(ln0) + " " + (aoff + "")) }
        if op0 == "FUNC"  { funcTabB = sbAppend(funcTabB, "\n" + headName(ln0) + " " + (aoff + "")) }
        let bs = toInt(opBytesScoped(ir, i, scope, globalTab, declared))
        aoff = aoff + bs
        codeSize = codeSize + bs
        i = i + 1
    }
    let labelTab = sbToString(labelTabB)
    let funcTab = sbToString(funcTabB)

    let allocOff  = HDR + START + codeSize
    let dataOff = (allocOff + 88*512) + 1
    // Load base = 0x7F000000 (= 32512<<16) so the int/pointer threshold is high
    // enough for real ints (matches the x86 backend). The backend itself can't hold
    // a >=0x7F000000 value (its own int ceiling), so all addresses stay as OFFSETS
    // and 0x7F00 is folded into the movk high half at emit time.

    let strBytes = 0
    i = 0
    while i < nlines {
        let l0 = getLine(ir, i)
        if isStrPush(l0) == "1" { strBytes = strBytes + (len(quoted(l0)) + 1) }
        i = i + 1
    }
    // Field-name table (for dot syntax: SETFIELD/GETFIELD names are immediates).
    // Stored right after the string literals; one entry per op (no dedup).
    let fieldBase = dataOff + strBytes
    let fieldBytes = 0
    i = 0
    while i < nlines {
        let lf = getLine(ir, i)
        let opf = opcode(lf)
        if opf == "SETFIELD" || opf == "GETFIELD" { fieldBytes = fieldBytes + (len(operand(lf)) + 1) }
        i = i + 1
    }
    let total = fieldBase + fieldBytes
    let heapOff = (total + 15) / 16 * 16            // heap start (offset from load base)
    let opOff = heapOff + 268435456 + 65536         // x20 start = heap + 256 MiB + 64 KiB (heap grows up from heapOff toward here; op stack grows down from here — 256 MiB keeps them apart so self-hosting big files doesn't collide)

    // ── _start: x20=op stack, x22=heap, bl __main__, exit(0) ──────────────────
    let mainOff = toInt(funcVaddrOf(funcTab, "__main__"))
    // capture argc/argv from the entry stack (sp=argc, [sp+8]=&argv[0]) into GB
    // slots 8/9 (GB+64/+72) BEFORE any function touches sp. GB = load_base+opOff.
    let code = sbAppend(sbNew(), e_ldr0(10, 31) + e_addi(11, 31, 8))                            // [0,4] x10=argc, x11=&argv[0]
    code = sbAppend(code, e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536))        // [8,12] x9=GB
    code = sbAppend(code, e_str8(10, 9, 8) + e_str8(11, 9, 9))                                  // [16,20] GB+64=argc; GB+72=argv
    code = sbAppend(code, e_addi(12, 10, 1) + e_movz(13, 3) + e_lslv(12, 12, 13) + e_addr(12, 11, 12) + e_str8(12, 9, 10))  // [24,28,32,36,40] envp = argv+(argc+1)*8 -> GB+80
    code = sbAppend(code, e_movz(20, opOff % 65536) + e_movk16(20, 32512 + opOff / 65536))      // [44,48] x20=op stack
    code = sbAppend(code, e_movz(22, heapOff % 65536) + e_movk16(22, 32512 + heapOff / 65536))  // [52,56] x22=heap
    if mainOff == 0 {
        code = sbAppend(code, e_movz(0, 0) + e_nop())
    } else {
        code = sbAppend(code, e_bl(mainOff - (HDR + 60)))
        code = sbAppend(code, e_bl((allocOff + 5*512) - (HDR + 64)))
    }
    code = sbAppend(code, e_movz(8, 93) + e_svc())                               // exit(atoi(main result)); libraries exit 0
    let off = HDR + START

    // ── functions: each gets a frame on sp (x19=locals base); op stack is x20 ──
    let curF = 0
    let curFName = ""
    let curDeclared = ""
    let frame = 0
    let curSlots = ""                 // per-function local-slot table (rebuilt at each FUNC)
    let strCursor = dataOff           // running offset into the string-literal data
    let fieldCursor = fieldBase       // running offset into the field-name table
    i = 0
    while i < nlines {
        let ln = getLine(ir, i)
        let op = opcode(ln)
        if op == "PARAM" || op == "LOCAL" { curDeclared = curDeclared + "\n" + operand(ln) + " " }
        if op == "FUNC" {
            curF = i
            curFName = headName(ln)
            curDeclared = ""
            let isMain = "0"
            if curFName == "__main__" { isMain = "1" }
            curSlots = buildSlots(ir, i, globalTab, isMain)
            let argc = toInt(funcArgc(ln))
            let localCount = toInt(countLocals(ir, i, globalTab, isMain))
            if localCount > 255 { printErr("aarch64 function has too many locals\n")  exit(1) }
            frame = localCount * 16
            code = sbAppend(code, e_subi(31, 31, 16) + e_str0(19, 31) + e_str8(30, 31, 1))   // save x19, x30
            code = sbAppend(code, e_subi(31, 31, frame) + e_addi(19, 31, 0))                 // alloc locals, x19=sp
            if isMain == "1" {
                code = sbAppend(code, e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536) + e_str8(19, 9, 11))  // GB+88 = main frame
            }
            let p = 0
            while p < argc {                                                        // pop args -> param slots
                code = sbAppend(code, e_ldr0(0, 20) + e_addi(20, 20, 16) + e_strIdx(0, 19, argc - 1 - p))
                p = p + 1
            }
            off = off + (5 + 3 * argc) * 4
            if isMain == "1" { off = off + 12 }
        }
        if op == "PUSH" {
            if isStrPush(ln) == "1" {
                let sOff = strCursor                              // O(1): running data offset (was O(n) full-IR re-walk per string)
                strCursor = strCursor + (len(quoted(ln)) + 1)
                code = sbAppend(code, e_movz(0, sOff % 65536) + e_movk16(0, 32512 + sOff / 65536) + c_push())
                off = off + 16
            } else if indexOf(operand(ln), ".") >= 0 {
                let lit = operand(ln)
                let neg = 0  let p = 0
                if lit[0] == "-" { neg = 1  p = 1 }
                let m = 0  let frac = 0  let dotted = 0
                while p < len(lit) {
                    let ch = lit[p]
                    if ch == "." { dotted = 1 }
                    else { m = m * 10 + toInt(ch)  if dotted == 1 { frac = frac + 1 } }
                    p = p + 1
                }
                let scale = 1  let si = 0
                while si < frac { scale = scale * 10  si = si + 1 }
                code = sbAppend(code, c_load64(0, m) + e_scvtf(0, 0) + c_load64(0, scale) + e_scvtf(1, 0) + e_fdiv(0, 0, 1))
                if neg == 1 { code = sbAppend(code, e_fneg(0, 0)) } else { code = sbAppend(code, e_nop()) }
                code = sbAppend(code, e_bl((allocOff + 56*512) - (off + 48)) + c_push())
                off = off + 60
            } else {
                code = sbAppend(code, c_loadImm(parseImm(operand(ln))) + c_push())
                off = off + toInt(immBytes(operand(ln)))
            }
        }
        if op == "FUNCPTR" {
            let fpOff = toInt(funcVaddrOf(funcTab, operand(ln)))
            code = sbAppend(code, e_movz(0, fpOff % 65536) + e_movk16(0, 32512 + fpOff / 65536) + c_push())
            off = off + 16
        }
        if op == "STORE" {
            let nm = operand(ln)
            if curFName != "__main__" && tabHas(globalTab, nm) == "1" && indexOf(curDeclared, "\n" + nm + " ") < 0 {
                let gs = toInt(tabLookup(globalTab, nm))
                code = sbAppend(code, c_pop0() + e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536) + e_ldr8(9, 9, 11) + e_strIdx(0, 9, gs))
                off = off + 24
            } else { code = sbAppend(code, c_pop0() + e_strIdx(0, 19, toInt(tabLookup(curSlots, nm))))  off = off + 12 }
        }
        if op == "LOAD" {
            let nm = operand(ln)
            if curFName != "__main__" && tabHas(globalTab, nm) == "1" && indexOf(curDeclared, "\n" + nm + " ") < 0 {
                let gs = toInt(tabLookup(globalTab, nm))
                code = sbAppend(code, e_movz(9, opOff % 65536) + e_movk16(9, 32512 + opOff / 65536) + e_ldr8(9, 9, 11) + e_ldrIdx(0, 9, gs) + c_push())
                off = off + 24
            } else { code = sbAppend(code, e_ldrIdx(0, 19, toInt(tabLookup(curSlots, nm))) + c_push())  off = off + 12 }
        }
        if op == "ADD" { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 2*512) - (off + 16)) + c_push())  off = off + 28 }  // polymorphic via kr_plus
        if op == "CAT" { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 83*512) - (off + 16)) + c_push())  off = off + 28 }  // forced concat, never numeric addition
        if op == "SUB" { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_subr(0, 10, 0) + c_push())  off = off + 52 }
        if op == "MUL" { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_mul(0, 10, 0) + c_push())   off = off + 52 }
        if op == "DIV" { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_sdiv(0, 10, 0) + c_push())  off = off + 52 }
        if op == "MOD" { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_sdiv(2, 10, 0) + e_msub(0, 2, 0, 10) + c_push())  off = off + 56 }
        // s[idx] -> kr_index (i-th CHARACTER). pop0->x0=idx, pop1->x1=s. 40 bytes.
        // (Element access on a comma-collection uses split(coll, i), not [].)
        if op == "INDEX" { code = sbAppend(code, c_pop0() + c_pop1() + e_movr(11, 1) + e_bl((allocOff + 5*512) - (off + 20)) + e_movr(1, 11) + e_bl((allocOff + 29*512) - (off + 28)) + c_push())  off = off + 40 }
        // p.x = v -> kr_setfield(env, name_imm, val). Stack: val(top), env. 36 bytes.
        if op == "SETFIELD" {
            code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16))              // pop val -> x2
            code = sbAppend(code, e_ldr0(0, 20) + e_addi(20, 20, 16))              // pop env -> x0
            code = sbAppend(code, e_movz(1, fieldCursor % 65536) + e_movk16(1, 32512 + fieldCursor / 65536))  // x1 = &name
            code = sbAppend(code, e_bl((allocOff + 33*512) - (off + 24)) + c_push())
            fieldCursor = fieldCursor + (len(operand(ln)) + 1)
            off = off + 36
        }
        // p.x -> kr_getfield(env, name_imm). Stack: env(top). 28 bytes.
        if op == "GETFIELD" {
            code = sbAppend(code, e_ldr0(1, 20) + e_addi(20, 20, 16))              // pop env -> x1
            code = sbAppend(code, e_movz(0, fieldCursor % 65536) + e_movk16(0, 32512 + fieldCursor / 65536))  // x0 = &name
            code = sbAppend(code, e_bl((allocOff + 34*512) - (off + 16)) + c_push())
            fieldCursor = fieldCursor + (len(operand(ln)) + 1)
            off = off + 28
        }
        if op == "STRUCTNEW" { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
        if op == "POP" { code = sbAppend(code, e_addi(20, 20, 16))  off = off + 4 }
        if op == "LT"  { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 38*512) - (off + 16)) + e_cmpi0(0) + e_cset(0, 10) + c_push())  off = off + 36 }
        if op == "GT"  { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 38*512) - (off + 16)) + e_cmpi0(0) + e_cset(0, 13) + c_push())  off = off + 36 }
        // EQ/NEQ are polymorphic (string contents OR numeric) via kr_eq.
        if op == "EQ"  { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 27*512) - (off + 16)) + c_push())   off = off + 28 }
        if op == "NEQ" { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 27*512) - (off + 16)) + e_cmpi0(0) + e_cset(0, 1) + c_push())   off = off + 36 }
        if op == "LTE" { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 38*512) - (off + 16)) + e_cmpi0(0) + e_cset(0, 12) + c_push())  off = off + 36 }
        if op == "GTE" { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 38*512) - (off + 16)) + e_cmpi0(0) + e_cset(0, 11) + c_push())  off = off + 36 }
        if op == "JUMP" { code = sbAppend(code, e_b(toInt(labelAbsOffset(labelTab, curFName + ":" + operand(ln))) - off))  off = off + 4 }
        if op == "JUMPIFNOT" { code = sbAppend(code, c_pop0() + e_bl((allocOff + 28*512) - (off + 8)) + e_cbz(0, toInt(labelAbsOffset(labelTab, curFName + ":" + operand(ln))) - (off + 12)))  off = off + 16 }
        if op == "JUMPIF" { code = sbAppend(code, c_pop0() + e_bl((allocOff + 28*512) - (off + 8)) + e_cbnz(0, toInt(labelAbsOffset(labelTab, curFName + ":" + operand(ln))) - (off + 12)))  off = off + 16 }
        if op == "NOT" { code = sbAppend(code, c_pop0() + e_bl((allocOff + 28*512) - (off + 8)) + e_movz(1, 1) + e_eor(0, 0, 1) + c_push())  off = off + 28 }
        if op == "NEG" {
            code = sbAppend(code, c_pop0() + e_movzHi(9, 32512) + e_cmp(0, 9) + e_blt(20))
            code = sbAppend(code, e_bl((allocOff + 54*512) - (off + 20)) + e_fneg(0, 0) + e_bl((allocOff + 56*512) - (off + 28)))
            code = sbAppend(code, e_b(8) + e_subr(0, 31, 0) + c_push())
            off = off + 48
        }
        if op == "CALL" {
            let cn = headName(ln)
            // bitwise builtins arrive as generic CALLs (front-end emits CALL, not BUILTIN).
            if cn == "bitAnd" { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_and(0, 10, 0) + c_push())  off = off + 52 }
            if cn == "bitOr"  { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_orr(0, 10, 0) + c_push())  off = off + 52 }
            if cn == "bitXor" { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_eor(0, 10, 0) + c_push())  off = off + 52 }
            if cn == "bitNot" { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_orn(0, 31, 0) + c_push())  off = off + 24 }
            if cn == "shl" { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_lslv(0, 10, 0) + c_push())  off = off + 52 }
            if cn == "shr" { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_lsrv(0, 10, 0) + c_push())  off = off + 52 }
            if cn == "repeat" { code = sbAppend(code, c_pop0() + c_pop1() + e_movr(11, 1) + e_bl((allocOff + 5*512) - (off + 20)) + e_movr(1, 11) + e_bl((allocOff + 16*512) - (off + 28)) + c_push())  off = off + 40 }
            if cn == "hex" { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_bl((allocOff + 7*512) - (off + 12)) + c_push())  off = off + 24 }
            // C-like raw memory ops (front-end emits these as generic CALLs).
            if cn == "rawAlloc"   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 41*512) - (off + 8)) + c_push())  off = off + 20 }
            if cn == "rawFree"    { code = sbAppend(code, c_pop0() + e_bl((allocOff + 42*512) - (off + 8)) + c_push())  off = off + 20 }
            if cn == "rawRealloc" { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 43*512) - (off + 16)) + c_push())  off = off + 28 }  // pop n->x1, ptr->x0
            if cn == "rawReadQword"  { code = sbAppend(code, c_pop0() + c_pop1() + e_addr(0, 1, 0) + e_ldr0(0, 0) + c_push())  off = off + 32 }  // [ptr+off]
            if cn == "rawWriteQword" { code = sbAppend(code, c_pop0() + c_pop1() + e_ldr0(2, 20) + e_addi(20, 20, 16) + e_addr(2, 2, 1) + e_str0(0, 2) + c_push())  off = off + 40 }  // [ptr+off]=val
            if cn == "rawReadByte"   { code = sbAppend(code, c_pop0() + c_pop1() + e_addr(0, 1, 0) + e_ldrb0(0, 0) + c_push())  off = off + 32 }
            if cn == "rawReadWord"   { code = sbAppend(code, c_pop0() + c_pop1() + e_ldrhO(0, 1, 0) + c_push())  off = off + 28 }  // u16 [ptr+off]
            if cn == "rawWriteWord"  { code = sbAppend(code, c_pop0() + c_pop1() + e_ldr0(2, 20) + e_addi(20, 20, 16) + e_strhR(0, 2, 1) + c_push())  off = off + 36 }  // [ptr+off]=val u16
            if cn == "ptrAdd"     { code = sbAppend(code, c_pop0() + c_pop1() + e_movr(11, 1) + e_bl((allocOff + 5*512) - (off + 20)) + e_movr(1, 11) + e_addr(0, 1, 0) + c_push())  off = off + 40 }  // ptr + numeric offset
            // ptrToInt(p) -> DECIMAL STRING of the raw address (per w2l_ptr_classification:
            // stringify so it routes through normal string handling, no smart-int collision).
            if cn == "ptrToInt"   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 1*512) - (off + 8)) + c_push())  off = off + 20 }
            if cn == "intToPtr"   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + c_push())  off = off + 20 }  // parse decimal string -> raw ptr
            if cn == "ptrEq"      { code = sbAppend(code, c_pop0() + c_pop1() + e_cmp(0, 1) + e_cset(0, 1) + c_push())  off = off + 32 }  // raw int64 compare -> 1 if equal (cset cc=NE: csinc NE = 1 when Z/EQ)
            // fdReadN and ioctl are CALL aliases in the frontend, not BUILTINs.
            let callSlot = 0
            if cn == "ioctl" || cn == "fdReadN" { callSlot = toInt(syscallBuiltinSlot(cn)) }
            if callSlot > 0 {
                let callArgs = toInt(syscallBuiltinArgs(cn))
                let kc = sbNew()
                let cp = callArgs - 1
                while cp >= 0 {
                    kc = sbAppend(kc, e_ldr0(cp, 20) + e_addi(20, 20, 16))
                    cp = cp - 1
                }
                kc = sbAppend(kc, e_bl((allocOff + callSlot * 512) - (off + callArgs * 8)) + c_push())
                code = sbAppend(code, sbToString(kc))
                off = off + callArgs * 8 + 12
            }
            if cn == "writeBytes" { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 32*512) - (off + 16)) + c_push())  off = off + 28 }  // raw bytes: hex-decode "xHH" -> file
            if cn != "bitAnd" && cn != "bitOr" && cn != "bitXor" && cn != "bitNot" && cn != "shl" && cn != "shr" && cn != "repeat" && cn != "hex" && cn != "rawAlloc" && cn != "rawFree" && cn != "rawRealloc" && cn != "rawReadQword" && cn != "rawWriteQword" && cn != "rawReadByte" && cn != "rawReadWord" && cn != "rawWriteWord" && cn != "writeBytes" && cn != "ptrAdd" && cn != "ptrToInt" && cn != "intToPtr" && cn != "ptrEq" && callSlot == 0 {
                code = sbAppend(code, e_bl(toInt(funcVaddrOf(funcTab, cn)) - off))  off = off + 4
            }
        }
        if op == "BUILTIN" {
            let b = operand(ln)
            let builtinSlot = toInt(syscallBuiltinSlot(b))
            if builtinSlot > 0 {
                let builtinArgs = toInt(syscallBuiltinArgs(b))
                let kc = sbNew()
                let bp = builtinArgs - 1
                while bp >= 0 {
                    kc = sbAppend(kc, e_ldr0(bp, 20) + e_addi(20, 20, 16))
                    bp = bp - 1
                }
                kc = sbAppend(kc, e_bl((allocOff + builtinSlot * 512) - (off + builtinArgs * 8)) + c_push())
                code = sbAppend(code, sbToString(kc))
                off = off + builtinArgs * 8 + 12
            }
            if startsWith(b, "fadd") || startsWith(b, "fsub") || startsWith(b, "fmul") || startsWith(b, "fdiv") {
                code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 54*512) - (off + 16)) + e_bl((allocOff + 55*512) - (off + 20)))
                if startsWith(b, "fadd") { code = sbAppend(code, e_fadd(0, 0, 1)) }
                else if startsWith(b, "fsub") { code = sbAppend(code, e_fsub(0, 0, 1)) }
                else if startsWith(b, "fmul") { code = sbAppend(code, e_fmul(0, 0, 1)) }
                else { code = sbAppend(code, e_fdiv(0, 0, 1)) }
                code = sbAppend(code, e_bl((allocOff + 56*512) - (off + 28)) + c_push())
                off = off + 40
            }
            if startsWith(b, "feq") || startsWith(b, "flt") || startsWith(b, "fgt") {
                code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 54*512) - (off + 16)) + e_bl((allocOff + 55*512) - (off + 20)) + e_fcmp(0, 1))
                code = sbAppend(code, e_cset(2, 6))                 // ordered flag; NaN clears every predicate
                if startsWith(b, "flt") { code = sbAppend(code, e_cset(0, 10)) }
                else if startsWith(b, "fgt") { code = sbAppend(code, e_cset(0, 13)) }
                else { code = sbAppend(code, e_cset(0, 1)) }
                code = sbAppend(code, e_and(0, 0, 2) + c_push())
                off = off + 48
            }
            if startsWith(b, "fsqrt") || startsWith(b, "ffloor") || startsWith(b, "fceil") {
                code = sbAppend(code, c_pop0() + e_bl((allocOff + 54*512) - (off + 8)))
                if startsWith(b, "fsqrt") { code = sbAppend(code, e_fsqrt(0, 0)) }
                else if startsWith(b, "ffloor") { code = sbAppend(code, e_frintm(0, 0)) }
                else { code = sbAppend(code, e_frintp(0, 0)) }
                code = sbAppend(code, e_bl((allocOff + 56*512) - (off + 16)) + c_push())
                off = off + 28
            }
            if startsWith(b, "fround") {
                code = sbAppend(code, c_pop0() + e_bl((allocOff + 54*512) - (off + 8)))
                code = sbAppend(code, e_fcmp0(0) + e_cset(6, 5) + e_fabs(0, 0))
                code = sbAppend(code, e_movz(1, 1) + e_scvtf(1, 1) + e_movz(2, 2))
                code = sbAppend(code, e_scvtf(2, 2) + e_fdiv(1, 1, 2))
                code = sbAppend(code, e_fadd(0, 0, 1) + e_frintm(0, 0))
                code = sbAppend(code, e_cbz(6, 8) + e_fneg(0, 0))
                code = sbAppend(code, e_bl((allocOff + 56*512) - (off + 60)) + c_push())
                off = off + 72
            }
            if startsWith(b, "intToFloat") { code = sbAppend(code, c_pop0() + e_scvtf(0, 0) + e_bl((allocOff + 56*512) - (off + 12)) + c_push())  off = off + 24 }
            if startsWith(b, "floatToInt") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 54*512) - (off + 8)) + e_fcvtzs(0, 0) + c_push())  off = off + 24 }
            if startsWith(b, "fformat") { code = sbAppend(code, c_pop1() + c_pop0() + e_bl((allocOff + 57*512) - (off + 16)) + c_push())  off = off + 28 }
            if startsWith(b, "isTruthy") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 28*512) - (off + 8)) + c_push())  off = off + 20 }
            // min/max(a,b): pop b->x0, a->x1; cmp a,b; csel. cond LT=11 (min), GT=12 (max). 32 bytes.
            // (bitwise builtins arrive as CALL, handled in the CALL branch below.)
            if startsWith(b, "min") { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_cmp(10, 0) + e_csel(0, 10, 0, 11) + c_push())  off = off + 56 }
            if startsWith(b, "max") { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_cmp(10, 0) + e_csel(0, 10, 0, 12) + c_push())  off = off + 56 }
            // hex/bin(n) -> string (coerce numeric text first). 24 bytes.
            if startsWith(b, "hex") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_bl((allocOff + 7*512) - (off + 12)) + c_push())  off = off + 24 }
            if startsWith(b, "bin") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_bl((allocOff + 8*512) - (off + 12)) + c_push())  off = off + 24 }
            // padLeft/padRight(s,width,pad): coerce width and stringify integer s. 88 bytes.
            if startsWith(b, "padLeft") {
                code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16))   // [0] pop pad->x2
                code = sbAppend(code, e_ldr0(1, 20) + e_addi(20, 20, 16))   // [8] pop width->x1
                code = sbAppend(code, e_movr(12, 2) + e_movr(0, 1))         // [16,20] save pad; width
                code = sbAppend(code, e_bl((allocOff + 5*512) - (off + 24)))         // [24] atoi(width)
                code = sbAppend(code, e_movr(1, 0) + e_movr(2, 12))         // [28,32] width; pad
                code = sbAppend(code, e_ldr0(0, 20) + e_addi(20, 20, 16))   // [36] pop s->x0
                code = sbAppend(code, e_movzHi(9, 32512) + e_cmp(0, 9))     // [44,48] x9=VBASE; cmp
                code = sbAppend(code, e_bge(24))                            // [52] s>=VBASE -> .skip (76)
                code = sbAppend(code, e_movr(11, 1) + e_movr(12, 2))        // [56] save width,pad
                code = sbAppend(code, e_bl((allocOff + 1*512) - (off + 64)))         // [64] x0=str(s)
                code = sbAppend(code, e_movr(1, 11) + e_movr(2, 12))        // [68,72] restore width,pad
                code = sbAppend(code, e_bl((allocOff + 9*512) - (off + 76)))        // [76] .skip
                code = sbAppend(code, c_push())                             // [80]
                off = off + 88
            }
            if startsWith(b, "padRight") {
                code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16))
                code = sbAppend(code, e_ldr0(1, 20) + e_addi(20, 20, 16))
                code = sbAppend(code, e_movr(12, 2) + e_movr(0, 1))
                code = sbAppend(code, e_bl((allocOff + 5*512) - (off + 24)))
                code = sbAppend(code, e_movr(1, 0) + e_movr(2, 12))
                code = sbAppend(code, e_ldr0(0, 20) + e_addi(20, 20, 16))
                code = sbAppend(code, e_movzHi(9, 32512) + e_cmp(0, 9))
                code = sbAppend(code, e_bge(24))
                code = sbAppend(code, e_movr(11, 1) + e_movr(12, 2))
                code = sbAppend(code, e_bl((allocOff + 1*512) - (off + 64)))
                code = sbAppend(code, e_movr(1, 11) + e_movr(2, 12))
                code = sbAppend(code, e_bl((allocOff + 10*512) - (off + 76)))
                code = sbAppend(code, c_push())
                off = off + 88
            }
            // 1-arg string->string transforms (kr_toupper/tolower/reverse). 20 bytes.
            if startsWith(b, "toUpper") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 11*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "toLower") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 12*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "reverse") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 13*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "strReverse") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 13*512) - (off + 8)) + c_push())  off = off + 20 }
            // 2-arg string builtins: pop0->x0 (2nd arg), pop1->x1 (1st arg); bl; push. 28 bytes.
            if startsWith(b, "startsWith") { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 14*512) - (off + 16)) + c_push())  off = off + 28 }
            if startsWith(b, "endsWith")   { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 15*512) - (off + 16)) + c_push())  off = off + 28 }
            if startsWith(b, "repeat")     { code = sbAppend(code, c_pop0() + c_pop1() + e_movr(11, 1) + e_bl((allocOff + 5*512) - (off + 20)) + e_movr(1, 11) + e_bl((allocOff + 16*512) - (off + 28)) + c_push())  off = off + 40 }
            if startsWith(b, "contains")   { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 17*512) - (off + 16)) + c_push())  off = off + 28 }
            if startsWith(b, "indexOf")    { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 18*512) - (off + 16)) + c_push())  off = off + 28 }
            if startsWith(b, "trim")       { code = sbAppend(code, c_pop0() + e_bl((allocOff + 19*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "split")      { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + c_pop1() + e_bl((allocOff + 20*512) - (off + 20)) + c_push())  off = off + 32 }  // idx via atoi (int-safe): accepts int or numeric-string index
            if startsWith(b, "lineCount")  { code = sbAppend(code, c_pop0() + e_bl((allocOff + 39*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "getLine")    { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + c_pop1() + e_bl((allocOff + 40*512) - (off + 20)) + c_push())  off = off + 32 }  // idx via atoi; kr_getline = kr_split sep '\n'
            if startsWith(b, "count")      { code = sbAppend(code, c_pop0() + e_bl((allocOff + 21*512) - (off + 8)) + c_push())  off = off + 20 }
            // abs(x): coerce numeric text, then signed abs. 32 bytes.
            if startsWith(b, "abs")        { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_cmpi0(0) + e_bge(8) + e_subr(0, 31, 0) + c_push())  off = off + 32 }
            // pow(base, exp): coerce both; kr_pow(x1=base,x0=exp). 56 bytes.
            if startsWith(b, "pow")        { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_movr(1, 10) + e_bl((allocOff + 22*512) - (off + 44)) + c_push())  off = off + 56 }
            // range(n): coerce end; start=0; kr_range. 28 bytes.
            if startsWith(b, "range 1")    { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_movr(1, 0) + e_bl((allocOff + 23*512) - (off + 16)) + c_push())  off = off + 28 }
            // range(start,end): coerce both; kr_range. 56 bytes.
            if startsWith(b, "range 2")    { code = sbAppend(code, c_pop1() + c_pop0() + emitCoerce2((allocOff + 5*512), off + 16) + e_movr(1, 10) + e_bl((allocOff + 23*512) - (off + 44)) + c_push())  off = off + 56 }
            // StringBuilder: sbNew (0-arg), sbAppend (handle,s -> x1=handle,x0=s), sbToString (handle).
            if startsWith(b, "sbNew")      { code = sbAppend(code, e_bl((allocOff + 24*512) - off) + c_push())  off = off + 12 }
            if startsWith(b, "sbAppend")   { code = sbAppend(code, c_pop0() + c_pop1() + e_movzHi(9, 32512) + e_cmp(0, 9) + e_bge(16) + e_movr(11, 1) + e_bl((allocOff + 1*512) - (off + 32)) + e_movr(1, 11) + e_bl((allocOff + 25*512) - (off + 40)) + c_push())  off = off + 52 }
            if startsWith(b, "sbToString") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 26*512) - (off + 8)) + c_push())  off = off + 20 }
            // exit(code): pop x0; SYS_exit(93); (push is dead, never reached). 24 bytes.
            if startsWith(b, "exit")       { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_movz(8, 93) + e_svc() + c_push())  off = off + 28 }
            if startsWith(b, "bufStr ") { code = sbAppend(code, c_pop0() + c_push())  off = off + 12 }
            if startsWith(b, "bufGetDword ") { code = sbAppend(code, c_pop1() + e_movz(0, 0) + e_ldrwO(0, 1, 31) + c_push())  off = off + 24 }
            if startsWith(b, "bufGetWord ") { code = sbAppend(code, c_pop1() + e_movz(0, 0) + e_ldrhO(0, 1, 31) + c_push())  off = off + 24 }
            if startsWith(b, "bufGetQword ") { code = sbAppend(code, c_pop1() + e_movz(0, 0) + e_ldr0(0, 1) + c_push())  off = off + 24 }
            if startsWith(b, "bufSetDword ") { code = sbAppend(code, c_pop0() + c_pop1() + e_strw0(0, 1) + c_push())  off = off + 28 }
            if startsWith(b, "bufSetWord ") { code = sbAppend(code, c_pop0() + c_pop1() + e_strhR(0, 1, 31) + c_push())  off = off + 28 }
            if startsWith(b, "handleOut") { code = sbAppend(code, e_movz(0, 8) + e_bl(allocOff - off) + c_push())  off = off + 16 }
            if startsWith(b, "handleGet") { code = sbAppend(code, c_pop0() + e_ldr0(0, 0) + c_push())  off = off + 20 }
            if startsWith(b, "handleInt") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 1*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "toHandle") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "ptrDeref") { code = sbAppend(code, c_pop0() + e_ldr0(0, 0) + c_push())  off = off + 20 }
            if startsWith(b, "ptrIndex") { code = sbAppend(code, c_pop0() + c_pop1() + e_movr(11, 1) + e_bl((allocOff + 5*512) - (off + 20)) + e_movr(1, 11) + e_movz(2, 3) + e_lslv(0, 0, 2) + e_addr(0, 1, 0) + c_push())  off = off + 48 }
            // bufNew(size): alloc(size) -> ptr. pop0->x0=size; bl alloc; push. 20 bytes.
            if startsWith(b, "bufNew ")    { code = sbAppend(code, c_pop0() + e_bl(allocOff - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "bufSetQwordAt ") {
                code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16) + e_ldr0(1, 20) + e_addi(20, 20, 16) + e_ldr0(0, 20) + e_addi(20, 20, 16))
                code = sbAppend(code, e_addr(0, 0, 1) + e_str0(2, 0) + e_movr(0, 2) + c_push())
                off = off + 44
            }
            if startsWith(b, "bufSetWordAt ") {
                code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16) + e_ldr0(1, 20) + e_addi(20, 20, 16) + e_ldr0(0, 20) + e_addi(20, 20, 16))
                code = sbAppend(code, e_addr(0, 0, 1) + e_strhR(2, 0, 31) + e_movr(0, 2) + c_push())
                off = off + 44
            }
            if startsWith(b, "bufSetDwordAt ") {
                code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16) + e_ldr0(1, 20) + e_addi(20, 20, 16) + e_ldr0(0, 20) + e_addi(20, 20, 16))
                code = sbAppend(code, e_addr(0, 0, 1) + e_strw0(2, 0) + e_movr(0, 2) + c_push())
                off = off + 44
            }
            // bufSetByte(buf, off, val): 3-arg. pop val->x2, off->x1, buf->x0; strb w2,[x0,x1]; push buf. 36 bytes.
            if startsWith(b, "bufSetByte ") { code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16) + e_ldr0(1, 20) + e_addi(20, 20, 16) + e_ldr0(0, 20) + e_addi(20, 20, 16) + e_strbR(2, 0, 1) + c_push())  off = off + 36 }
            // bufGetByte(buf, off): pop0->x0=off, pop1->x1=buf; ldrb w0,[x1,x0]; push. 28 bytes.
            if startsWith(b, "bufGetQwordAt ") { code = sbAppend(code, c_pop0() + c_pop1() + e_addr(0, 1, 0) + e_ldr0(0, 0) + c_push())  off = off + 32 }
            if startsWith(b, "bufGetByte ") { code = sbAppend(code, c_pop0() + c_pop1() + e_ldrbO(0, 1, 0) + c_push())  off = off + 28 }
            // bufGetWordAt(buf, off) -> u16 LE: ldrh w0,[buf+off] (ARM is little-endian). 28 bytes.
            if startsWith(b, "bufGetWordAt ") { code = sbAppend(code, c_pop0() + c_pop1() + e_ldrhO(0, 1, 0) + c_push())  off = off + 28 }
            // bufGetDwordAt(buf, off) -> u32 LE: ldr w0,[buf+off]. 28 bytes.
            if startsWith(b, "bufGetDwordAt ") { code = sbAppend(code, c_pop0() + c_pop1() + e_ldrwO(0, 1, 0) + c_push())  off = off + 28 }
            if startsWith(b, "bufGetWordAtBE ") { code = sbAppend(code, c_pop0() + c_pop1() + e_ldrhO(0, 1, 0) + e_rev16(0, 0) + c_push())  off = off + 32 }
            if startsWith(b, "bufGetDwordAtBE ") { code = sbAppend(code, c_pop0() + c_pop1() + e_ldrwO(0, 1, 0) + e_rev32(0, 0) + c_push())  off = off + 32 }
            if startsWith(b, "bufGetQwordAtBE ") { code = sbAppend(code, c_pop0() + c_pop1() + e_addr(0, 1, 0) + e_ldr0(0, 0) + e_rev64(0, 0) + c_push())  off = off + 36 }
            // unixConnect(path) -> socket(AF_UNIX=1,SOCK_STREAM=1,0) then connect(fd,
            // &sockaddr_un{family=1, sun_path=path}, 110). Returns fd, or negative
            // connect errno on failure. Builds sockaddr_un on sp. AF_UNIX transport
            // for pure-Krypton X11/Wayland. svc preserves x9(path)/x10(fd). 128 bytes.
            if startsWith(b, "unixConnect") {
                let kc = sbNew()
                kc = sbAppend(kc, c_pop0())                                  // [0]  x0 = path
                kc = sbAppend(kc, e_movr(9, 0))                              // [8]  x9 = path (survives socket svc)
                kc = sbAppend(kc, e_movz(0, 1) + e_movz(1, 1) + e_movz(2, 0))// [12,16,20] AF_UNIX, SOCK_STREAM, proto 0
                kc = sbAppend(kc, e_movz(8, 198) + e_svc())                  // [24,28] socket -> x0 = fd
                kc = sbAppend(kc, e_movr(10, 0) + e_subi(31, 31, 128))       // [32,36] x10=fd; sp -= 128 (sockaddr_un)
                kc = sbAppend(kc, e_movz(2, 1) + e_strb(2, 31) + e_strbO(31, 31, 1))  // [40,44,48] sun_family = 1 (LE u16)
                kc = sbAppend(kc, e_addi(3, 31, 2) + e_movr(4, 9))           // [52,56] dst=sp+2 (sun_path); src=path
                kc = sbAppend(kc, e_ldrb0(5, 4) + e_strb(5, 3) + e_cbz(5, 16))  // [60,64,68] .copy: b=[src]; [dst]=b; 0 -> .done(84)
                kc = sbAppend(kc, e_addi(4, 4, 1) + e_addi(3, 3, 1) + e_b(0 - 20))  // [72,76,80] src++; dst++; -> .copy(60)
                kc = sbAppend(kc, e_movr(0, 10) + e_addi(1, 31, 0))          // [84,88] .done: x0=fd; x1=sp (&addr)
                kc = sbAppend(kc, e_movz(2, 110) + e_movz(8, 203) + e_svc()) // [92,96,100] connect -> x0 = 0 / -errno
                kc = sbAppend(kc, e_addi(31, 31, 128))                       // [104] restore sp
                kc = sbAppend(kc, e_cbz(0, 8) + e_b(8))                      // [108,112] x0==0 ok -> .ok(116); else -> .push(120)
                kc = sbAppend(kc, e_movr(0, 10))                            // [116] .ok: x0 = fd
                kc = sbAppend(kc, c_push())                                 // [120] .push: push result
                code = sbAppend(code, sbToString(kc))
                off = off + 128
            }
            // readFile(path): pop0->x0=path; kr_readfile. 20 bytes.
            if startsWith(b, "readLine 1") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 84*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "readLine 0") { code = sbAppend(code, e_movz(0, 0) + e_bl((allocOff + 84*512) - (off + 4)) + c_push())  off = off + 16 }
            if startsWith(b, "input") { code = sbAppend(code, e_movz(0, 0) + e_bl((allocOff + 84*512) - (off + 4)) + c_push())  off = off + 16 }
            if startsWith(b, "readFile")   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 30*512) - (off + 8)) + c_push())  off = off + 20 }
            // argCount() -> argc-1 (0-arg); arg(idx) -> argv[idx+1] (idx via atoi, string index).
            // argCount must be checked first (it also startsWith "arg") -> else-if pair.
            if startsWith(b, "argCount") { code = sbAppend(code, e_bl((allocOff + 44*512) - off) + c_push())  off = off + 12 }
            else if startsWith(b, "arg") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_bl((allocOff + 45*512) - (off + 12)) + c_push())  off = off + 24 }
            if startsWith(b, "printErr")   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 46*512) - (off + 8)) + e_movz(0, 0) + c_push())  off = off + 24 }
            if startsWith(b, "isDigit")    { code = sbAppend(code, c_pop0() + e_bl((allocOff + 47*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "isAlpha") {
                code = sbAppend(code, c_pop0() + e_ldrb0(1, 0) + e_movz(2, 32))
                code = sbAppend(code, e_orr(1, 1, 2) + e_subi(1, 1, 97))
                code = sbAppend(code, e_movz(2, 27) + e_movz(0, 0))
                code = sbAppend(code, e_cmp(1, 2) + e_bhs(8) + e_movz(0, 1) + c_push())
                off = off + 52
            }
            if startsWith(b, "parseInt")   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "gcLiveCount") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcMark") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcSweep") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcReset") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcCheckpoint") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcRestore") { code = sbAppend(code, c_pop0() + e_movz(0, 0) + c_push())  off = off + 20 }
            if startsWith(b, "gcSlabCount") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcSlabBytes") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcSetThreshold") { code = sbAppend(code, c_pop0() + e_movz(0, 0) + c_push())  off = off + 20 }
            // replace(s, find, rep): pop rep->x2, find->x1, s->x0; kr_replace; push.
            if startsWith(b, "replace")    { code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16) + e_ldr0(1, 20) + e_addi(20, 20, 16) + e_ldr0(0, 20) + e_addi(20, 20, 16) + e_bl((allocOff + 49*512) - (off + 24)) + c_push())  off = off + 36 }
            if startsWith(b, "exec ")      { code = sbAppend(code, c_pop0() + e_bl((allocOff + 53*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "random") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 86*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "timestamp") { code = sbAppend(code, e_bl((allocOff + 87*512) - off) + c_push())  off = off + 12 }
            if startsWith(b, "environ")    { code = sbAppend(code, c_pop0() + e_bl((allocOff + 50*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "readProc")   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 52*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "ptrToInt")   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 1*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "intToPtr")   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "callPtr") {
                let csp = toInt(indexOf(b, " "))
                let cargc = toInt(substring(b, csp + 1, len(b)))
                let kc = sbNew()
                kc = sbAppend(kc, e_addi(17, 20, (cargc - 1) * 16))
                kc = sbAppend(kc, e_ldr0(16, 17) + e_blr(16))
                kc = sbAppend(kc, e_ldr0(0, 20) + e_addi(20, 20, 32))
                kc = sbAppend(kc, c_push())
                code = sbAppend(code, sbToString(kc))
                off = off + 28
            }
            if startsWith(b, "shellRun")   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 51*512) - (off + 8)) + c_push())  off = off + 20 }
            // writeFile(path, content): pop0->x0=content, pop1->x1=path; kr_writefile. 28 bytes.
            if startsWith(b, "writeFile")  { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 31*512) - (off + 16)) + c_push())  off = off + 28 }
            if startsWith(b, "kp") {
                let kc = sbNew()
                kc = sbAppend(kc, c_pop0())                         // pop arg -> x0
                kc = sbAppend(kc, e_bl((allocOff + 4*512) - (off + 8)))      // dispatch + print
                kc = sbAppend(kc, e_movz(0, 0))               // canonical no-value result
                kc = sbAppend(kc, c_push())                         // push dummy (IR POPs it)
                code = sbAppend(code, sbToString(kc))
                off = off + 24
            }
            if startsWith(b, "gcShadowCount") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcShadowPush") { code = sbAppend(code, e_addi(20, 20, 16) + e_movz(0, 0) + c_push())  off = off + 16 }
            if startsWith(b, "gcShadowPop") { code = sbAppend(code, e_addi(20, 20, 16) + e_movz(0, 0) + c_push())  off = off + 16 }
            // GC builtins: no-op for a bump allocator (no GC). Push 0.
            if startsWith(b, "gcCollect")    { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "gcAllocCount") { code = sbAppend(code, e_movz(10, opOff % 65536) + e_movk16(10, 32512 + opOff / 65536) + e_ldr8(0, 10, 3) + c_push())  off = off + 20 }
            if startsWith(b, "gcAllocated")  { code = sbAppend(code, e_movz(10, opOff % 65536) + e_movk16(10, 32512 + opOff / 65536) + e_ldr8(0, 10, 2) + c_push())  off = off + 20 }
            if startsWith(b, "gcLimit")      { code = sbAppend(code, e_movz(10, opOff % 65536) + e_movk16(10, 32512 + opOff / 65536) + e_ldr8(0, 10, 4) + c_push())  off = off + 20 }
            if startsWith(b, "gcSetLimit")   { code = sbAppend(code, c_pop0() + e_bl((allocOff + 5*512) - (off + 8)) + e_movz(10, opOff % 65536) + e_movk16(10, 32512 + opOff / 65536) + e_str8(0, 10, 4) + e_movz(0, 0) + c_push())  off = off + 36 }
            if startsWith(b, "gcFreelistCount") { code = sbAppend(code, e_movz(10, opOff % 65536) + e_movk16(10, 32512 + opOff / 65536) + e_ldr8(1, 10, 1) + e_movz(0, 0) + e_cbz(1, 16) + e_addi(0, 0, 1) + e_ldr0(1, 1) + e_b(0 - 12) + c_push())  off = off + 40 }  // [8]head;[12]cnt;[16].loop cbz->done(32);[20]cnt++;[24]cur=[cur];[28]->loop
            if startsWith(b, "gcWalkAllocs") { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "pause") { code = sbAppend(code, e_yield() + e_movz(0, 0) + c_push())  off = off + 16 }
            if startsWith(b, "mfence") { code = sbAppend(code, e_dmbIsh() + e_dsbIsh() + e_movz(0, 0) + c_push())  off = off + 20 }
            if startsWith(b, "lfence") { code = sbAppend(code, e_dmbIshld() + e_dsbIsh() + e_movz(0, 0) + c_push())  off = off + 20 }
            if startsWith(b, "sfence") { code = sbAppend(code, e_dmbIshst() + e_dsbIsh() + e_movz(0, 0) + c_push())  off = off + 20 }
            // rdtsc: mrs x0,cntvct_el0; keep low 30 bits (<<34>>34) so it fits the int tag. +push.
            if startsWith(b, "rdtsc")        { code = sbAppend(code, wordHL(54587, 57408) + e_movz(1, 34) + e_lslv(0, 0, 1) + e_lsrv(0, 0, 1) + c_push())  off = off + 24 }
            // structs (env linked list). structNew/envNew -> empty env (0).
            if startsWith(b, "structNew")  { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            if startsWith(b, "envNew")     { code = sbAppend(code, e_movz(0, 0) + c_push())  off = off + 12 }
            // setField(env,name,val): 3-arg pop val->x2,name->x1,env->x0; kr_setfield. 36 bytes.
            if startsWith(b, "setField")   { code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16) + e_ldr0(1, 20) + e_addi(20, 20, 16) + e_ldr0(0, 20) + e_addi(20, 20, 16) + e_bl((allocOff + 33*512) - (off + 24)) + c_push())  off = off + 36 }
            if startsWith(b, "envSet")     { code = sbAppend(code, e_ldr0(2, 20) + e_addi(20, 20, 16) + e_ldr0(1, 20) + e_addi(20, 20, 16) + e_ldr0(0, 20) + e_addi(20, 20, 16) + e_bl((allocOff + 33*512) - (off + 24)) + c_push())  off = off + 36 }
            // getField(env,name): pop name->x0, env->x1; kr_getfield. 28 bytes.
            if startsWith(b, "getField")   { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 34*512) - (off + 16)) + c_push())  off = off + 28 }
            if startsWith(b, "envGet")     { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 34*512) - (off + 16)) + c_push())  off = off + 28 }
            // hasField(env,name): pop name->x0, env->x1; kr_hasfield -> 1/0. 28 bytes.
            if startsWith(b, "hasField")   { code = sbAppend(code, c_pop0() + c_pop1() + e_bl((allocOff + 35*512) - (off + 16)) + c_push())  off = off + 28 }
            // structFields(env): pop env->x0; kr_structfields. 20 bytes.
            if startsWith(b, "structFields") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 36*512) - (off + 8)) + c_push())  off = off + 20 }
            if startsWith(b, "charAt") { code = sbAppend(code, c_pop0() + c_pop1() + e_movr(11, 1) + e_bl((allocOff + 5*512) - (off + 20)) + e_movr(1, 11) + e_bl((allocOff + 29*512) - (off + 28)) + c_push())  off = off + 40 }
            if startsWith(b, "isSpace") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 85*512) - (off + 8)) + c_push())  off = off + 20 }
            // charCode(s) -> first byte of s (int). 20 bytes.
            if startsWith(b, "charCode") {
                let kc = sbNew()
                kc = sbAppend(kc, c_pop0())
                kc = sbAppend(kc, e_ldrb0(0, 0))
                kc = sbAppend(kc, c_push())
                code = sbAppend(code, sbToString(kc))
                off = off + 20
            }
            // length(collection) -> element count (kr_count). MUST precede "len " so
            // "length" isn't mistaken for strlen. 20 bytes.
            if startsWith(b, "length") { code = sbAppend(code, c_pop0() + e_bl((allocOff + 21*512) - (off + 8)) + c_push())  off = off + 20 }
            // len(s) -> strlen (int), stringifying integer arguments first. 56 bytes.
            if startsWith(b, "len ") {
                let kc = sbNew()
                kc = sbAppend(kc, c_pop0())                  // x0 = value
                kc = sbAppend(kc, e_movzHi(9, 32512) + e_cmp(0, 9) + e_bge(8))
                kc = sbAppend(kc, e_bl((allocOff + 1*512) - (off + 20)))
                kc = sbAppend(kc, e_movz(1, 0))              // len=0
                kc = sbAppend(kc, e_ldrbO(2, 0, 1))          // .loop: w2=[x0+len]
                kc = sbAppend(kc, e_cbz(2, 12))              // 0 -> .done
                kc = sbAppend(kc, e_addi(1, 1, 1))           // len++
                kc = sbAppend(kc, e_b(0 - 12))               // loop
                kc = sbAppend(kc, e_movr(0, 1))              // x0 = len
                kc = sbAppend(kc, c_push())
                code = sbAppend(code, sbToString(kc))
                off = off + 56
            }
            // toStr(x) / kr_str(x) -> string (kr_str_int for ints; identity for pointers).
            if startsWith(b, "toStr") || startsWith(b, "kr_str") {
                let kc = sbNew()
                kc = sbAppend(kc, c_pop0())
                kc = sbAppend(kc, e_movzHi(9, 32512))
                kc = sbAppend(kc, e_cmp(0, 9))
                kc = sbAppend(kc, e_bge(8))                  // signed>=VBASE = pointer -> already a string
                kc = sbAppend(kc, e_bl((allocOff + 1*512) - (off + 20)))
                kc = sbAppend(kc, c_push())
                code = sbAppend(code, sbToString(kc))
                off = off + 32
            }
            // toInt(s) -> parse signed decimal prefix (kr_atoi). 20 bytes.
            if startsWith(b, "toInt") {
                let kc = sbNew()
                kc = sbAppend(kc, c_pop0())                       // x0 = string ptr
                kc = sbAppend(kc, e_bl((allocOff + 5*512) - (off + 8)))      // x0 = parsed int
                kc = sbAppend(kc, c_push())
                code = sbAppend(code, sbToString(kc))
                off = off + 20
            }
            // fromCharCode(n) -> 1-char string for byte n. Arg is a numeric STRING
            // (e.g. "65") or int; kr_atoi (int-safe) coerces to the code. 40 bytes.
            if startsWith(b, "fromCharCode") {
                let kc = sbNew()
                kc = sbAppend(kc, c_pop0())                       // x0 = code (string or int)
                kc = sbAppend(kc, e_bl((allocOff + 5*512) - (off + 8)))      // x0 = code as int
                kc = sbAppend(kc, e_movr(10, 0))                  // save code in x10
                kc = sbAppend(kc, e_movz(0, 2))                   // size = 2
                kc = sbAppend(kc, e_bl(allocOff - (off + 20)))    // x0 = buf
                kc = sbAppend(kc, e_strb(10, 0))                  // buf[0] = code
                kc = sbAppend(kc, e_strbO(31, 0, 1))             // buf[1] = NUL
                kc = sbAppend(kc, c_push())                       // push buf
                code = sbAppend(code, sbToString(kc))
                off = off + 40
            }
            // substring(s,start,end): coerce both bounds, then kr_substring. 80 bytes.
            if startsWith(b, "substring") {
                let kc = sbNew()
                kc = sbAppend(kc, e_ldr0(2, 20) + e_addi(20, 20, 16))   // pop end -> x2
                kc = sbAppend(kc, e_ldr0(1, 20) + e_addi(20, 20, 16))   // pop start -> x1
                kc = sbAppend(kc, e_ldr0(0, 20) + e_addi(20, 20, 16))   // pop s -> x0
                kc = sbAppend(kc, e_movr(10, 0) + e_movr(11, 1) + e_movr(12, 2))
                kc = sbAppend(kc, e_movr(0, 1) + e_bl((allocOff + 5*512) - (off + 40)))
                kc = sbAppend(kc, e_movr(13, 0) + e_movr(0, 12))
                kc = sbAppend(kc, e_bl((allocOff + 5*512) - (off + 52)) + e_movr(2, 0))
                kc = sbAppend(kc, e_movr(1, 13) + e_movr(0, 10) + e_bl((allocOff + 6*512) - (off + 68)))
                kc = sbAppend(kc, c_push())
                code = sbAppend(code, sbToString(kc))
                off = off + 80
            }
        }
        // Exception records live above the raw arena: [depth][addr,x20,x19,sp]...
        if op == "TRY" {
            let target = toInt(labelAbsOffset(labelTab, curFName + ":" + operand(ln)))
            code = sbAppend(code, emitTry(target, opOff))
            off = off + 64
        }
        if op == "ENDTRY" {
            code = sbAppend(code, emitEndTry(opOff))
            off = off + 24
        }
        if op == "THROW" {
            code = sbAppend(code, emitThrow(opOff))
            off = off + 100
        }
        // RETURN and END: epilogue (free locals, restore x19/x30, ret). For __main__
        // this returns to _start, which then exits(0).
        if op == "RETURN" { code = sbAppend(code, e_addi(31, 31, frame) + e_ldr0(19, 31) + e_ldr8(30, 31, 1) + e_addi(31, 31, 16) + e_ret())  off = off + 20 }
        if op == "END"    { code = sbAppend(code, e_movz(0, 0) + c_push() + e_addi(31, 31, frame) + e_ldr0(19, 31) + e_ldr8(30, 31, 1) + e_addi(31, 31, 16) + e_ret())  off = off + 32 }
        i = i + 1
    }

    if off != allocOff { printErr("aarch64 code size mismatch: " + (off + "") + " != " + (allocOff + "") + "\n")  exit(1) }
    if bufGetQwordAt(code, 8) != (allocOff - HDR) * 3 { printErr("aarch64 emitted code size mismatch: " + toStr(bufGetQwordAt(code, 8)) + " != " + toStr((allocOff - HDR) * 3) + "\n")  exit(1) }

    // helpers appended after main code, in layout order (alloc, str_int, plus, print)
    // built via sbAppend (not one long + chain) — the x86 backend miscompiles
    // long concat chains in this position and silently drops a term.
    let bb = sbNew()
    bb = sbAppend(bb, sbToString(code))
    bb = sbAppend(bb, padTo(emitAlloc(), 512))
    bb = sbAppend(bb, padTo(emitStrInt(allocOff, (allocOff + 1*512)), 512))
    bb = sbAppend(bb, padTo(emitPlus((allocOff + 1*512), allocOff, (allocOff + 5*512), (allocOff + 37*512), (allocOff + 2*512)), 512))
    bb = sbAppend(bb, padTo(emitPrint((allocOff + 88*512)), 512))
    bb = sbAppend(bb, padTo(emitKpDisp((allocOff + 4*512), (allocOff + 1*512), (allocOff + 3*512)), 512))
    bb = sbAppend(bb, padTo(emitAtoi(), 512))
    bb = sbAppend(bb, padTo(emitSubstr(allocOff, (allocOff + 6*512)), 512))
    bb = sbAppend(bb, padTo(emitHex(allocOff, (allocOff + 7*512)), 512))
    bb = sbAppend(bb, padTo(emitBin(allocOff, (allocOff + 8*512)), 512))
    bb = sbAppend(bb, padTo(emitPadLeft(allocOff, (allocOff + 9*512)), 512))
    bb = sbAppend(bb, padTo(emitPadRight(allocOff, (allocOff + 10*512)), 512))
    bb = sbAppend(bb, padTo(emitToUpper(allocOff, (allocOff + 11*512)), 512))
    bb = sbAppend(bb, padTo(emitToLower(allocOff, (allocOff + 12*512)), 512))
    bb = sbAppend(bb, padTo(emitReverse(allocOff, (allocOff + 13*512)), 512))
    bb = sbAppend(bb, padTo(emitStartsWith(), 512))
    bb = sbAppend(bb, padTo(emitEndsWith(), 512))
    bb = sbAppend(bb, padTo(emitRepeat(allocOff, (allocOff + 16*512)), 512))
    bb = sbAppend(bb, padTo(emitContains(), 512))
    bb = sbAppend(bb, padTo(emitIndexOf(), 512))
    bb = sbAppend(bb, padTo(emitTrim(allocOff, (allocOff + 19*512)), 512))
    bb = sbAppend(bb, padTo(emitSplit(allocOff, (allocOff + 20*512)), 512))
    bb = sbAppend(bb, padTo(emitCount(), 512))
    bb = sbAppend(bb, padTo(emitPow(), 512))
    bb = sbAppend(bb, padTo(emitRange(allocOff, (allocOff + 1*512), (allocOff + 23*512)), 512))
    bb = sbAppend(bb, padTo(emitSbNew(allocOff, (allocOff + 24*512)), 512))
    bb = sbAppend(bb, padTo(emitSbAppend(allocOff, (allocOff + 25*512)), 512))
    bb = sbAppend(bb, padTo(emitSbToString(), 512))
    bb = sbAppend(bb, padTo(emitEq((allocOff + 5*512), (allocOff + 37*512), (allocOff + 27*512)), 512))
    bb = sbAppend(bb, padTo(emitIsTruthy(), 512))
    bb = sbAppend(bb, padTo(emitIndex(allocOff, (allocOff + 29*512)), 512))
    bb = sbAppend(bb, padTo(emitReadFile(allocOff, (allocOff + 30*512)), 512))
    bb = sbAppend(bb, padTo(emitWriteFile(), 512))
    bb = sbAppend(bb, padTo(emitWriteBytes(allocOff, (allocOff + 48*512), (allocOff + 32*512)), 512))
    bb = sbAppend(bb, padTo(emitSetField(allocOff, (allocOff + 33*512)), 512))
    bb = sbAppend(bb, padTo(emitGetField(allocOff, (allocOff + 34*512)), 512))
    bb = sbAppend(bb, padTo(emitHasField(), 512))
    bb = sbAppend(bb, padTo(emitStructFields(allocOff, (allocOff + 2*512), (allocOff + 36*512)), 512))
    bb = sbAppend(bb, padTo(emitIsnum(), 512))
    bb = sbAppend(bb, padTo(emitCmp((allocOff + 5*512), (allocOff + 37*512), (allocOff + 38*512)), 512))
    bb = sbAppend(bb, padTo(emitLinecount(), 512))
    bb = sbAppend(bb, padTo(emitGetline(allocOff, opOff, (allocOff + 40*512)), 512))
    bb = sbAppend(bb, padTo(emitRawAlloc(opOff, (allocOff + 41*512)), 512))
    bb = sbAppend(bb, padTo(emitRawFree(opOff, (allocOff + 42*512)), 512))
    bb = sbAppend(bb, padTo(emitRawRealloc((allocOff + 41*512), (allocOff + 42*512), (allocOff + 43*512)), 512))
    bb = sbAppend(bb, padTo(emitArgcount(opOff), 512))
    bb = sbAppend(bb, padTo(emitArg(opOff), 512))
    bb = sbAppend(bb, padTo(emitPrinterr((allocOff + 88*512)), 512))
    bb = sbAppend(bb, padTo(emitIsdigit(), 512))
    bb = sbAppend(bb, padTo(emitStrlen(), 512))
    bb = sbAppend(bb, padTo(emitReplace((allocOff + 48*512), allocOff, (allocOff + 49*512)), 512))
    bb = sbAppend(bb, padTo(emitEnviron(opOff, allocOff, (allocOff + 50*512)), 512))
    bb = sbAppend(bb, padTo(emitShellrun(opOff, allocOff, (allocOff + 1*512), (allocOff + 51*512)), 512))
    bb = sbAppend(bb, padTo(emitReadProc(allocOff, (allocOff + 52*512)), 512))
    bb = sbAppend(bb, padTo(emitExec(opOff, allocOff, (allocOff + 53*512)), 512))
    bb = sbAppend(bb, padTo(emitFLoad1(), 512))
    bb = sbAppend(bb, padTo(emitFLoad2(), 512))
    bb = sbAppend(bb, padTo(emitFBox(allocOff, (allocOff + 56*512)), 512))
    bb = sbAppend(bb, padTo(emitFFormat(allocOff, (allocOff + 57*512)), 512))
    bb = sbAppend(bb, padTo(emitFdReadN(), 512))
    bb = sbAppend(bb, padTo(emitFdRead(allocOff, (allocOff + 59*512)), 512))
    bb = sbAppend(bb, padTo(emitFdWrite(), 512))
    bb = sbAppend(bb, padTo(emitFdClose(), 512))
    bb = sbAppend(bb, padTo(emitFdSetNonblock(), 512))
    bb = sbAppend(bb, padTo(emitIoctl(), 512))
    bb = sbAppend(bb, padTo(emitMemfdCreate(), 512))
    bb = sbAppend(bb, padTo(emitMmapShared(), 512))
    bb = sbAppend(bb, padTo(emitPtyMaster(), 512))
    bb = sbAppend(bb, padTo(emitPtySlaveName((allocOff + 1*512), (allocOff + 2*512), (allocOff + 67*512)), 512))
    bb = sbAppend(bb, padTo(emitPtyForkExec(opOff), 512))
    bb = sbAppend(bb, padTo(emitPtySetSize(), 512))
    bb = sbAppend(bb, padTo(emitSleepUs(), 512))
    bb = sbAppend(bb, padTo(emitWaitChild(), 512))
    bb = sbAppend(bb, padTo(emitProcAlive(), 512))
    bb = sbAppend(bb, padTo(emitSockMake(), 512))
    bb = sbAppend(bb, padTo(emitSockBind(), 512))
    bb = sbAppend(bb, padTo(emitSockListen(), 512))
    bb = sbAppend(bb, padTo(emitSockAccept(), 512))
    bb = sbAppend(bb, padTo(emitSockRecv(), 512))
    bb = sbAppend(bb, padTo(emitSockSend(), 512))
    bb = sbAppend(bb, padTo(emitSockClose(), 512))
    bb = sbAppend(bb, padTo(emitSockRecvStr(allocOff, (allocOff + 80*512)), 512))
    bb = sbAppend(bb, padTo(emitSockConnect(), 512))
    bb = sbAppend(bb, padTo(emitSockSendFd(), 512))
    bb = sbAppend(bb, padTo(emitConcat((allocOff + 1*512), allocOff, (allocOff + 83*512)), 512))
    bb = sbAppend(bb, padTo(emitReadline(allocOff, (allocOff + 84*512)), 512))
    bb = sbAppend(bb, padTo(emitIsSpace(), 512))
    bb = sbAppend(bb, padTo(emitRandom(), 512))
    bb = sbAppend(bb, padTo(emitTimestamp((allocOff + 1*512), (allocOff + 87*512)), 512))
    bb = sbAppend(bb, "")     // guards: x86 backend drops trailing sbAppends (scales w/ chain len)
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    bb = sbAppend(bb, "")
    let body = sbToString(bb)

    // data region: newline byte (at (allocOff + 88*512)) then string literals.
    // StringBuilder, not `data = data + ...`: the byte-wise concat is O(n²)
    // and exhausts the 256 MiB heap when compiling the 40k-line self-host IR.
    let dataB = sbNew()
    dataB = sbAppend(dataB, hexByte(10))                       // newline
    // string literals in order
    i = 0
    while i < nlines {
        let ln = getLine(ir, i)
        if isStrPush(ln) == "1" {
            let s = quoted(ln)
            let c = 0
            while c < len(s) {
                let hb = hexByte(charCode(substring(s, c, c + 1)))
                dataB = sbAppend(dataB, hb)
                c = c + 1
            }
            dataB = sbAppend(dataB, hexByte(0))
        }
        i = i + 1
    }
    // field-name table (dot syntax), in SETFIELD/GETFIELD order — matches fieldCursor
    i = 0
    while i < nlines {
        let ln = getLine(ir, i)
        let opf = opcode(ln)
        if opf == "SETFIELD" || opf == "GETFIELD" {
            let s = operand(ln)
            let c = 0
            while c < len(s) {
                let hb = hexByte(charCode(substring(s, c, c + 1)))
                dataB = sbAppend(dataB, hb)
                c = c + 1
            }
            dataB = sbAppend(dataB, hexByte(0))
        }
        i = i + 1
    }
    let data = sbToString(dataB)

    // ELF64 header (aarch64, ET_EXEC) + PT_LOAD (RWX); total/heapBase computed above
    let eh = hexByte(127) + "x45x4Cx46" + "x02x01x01x00" + "x00x00x00x00x00x00x00x00"
    eh = eh + "x02x00" + "xB7x00" + "x01x00x00x00"
    eh = eh + le8vaddr(HDR) + le8(64) + le8(0)
    eh = eh + "x00x00x00x00" + "x40x00" + "x38x00" + "x01x00" + "x00x00" + "x00x00" + "x00x00"
    let ph = "x01x00x00x00" + "x07x00x00x00"
    let memsz = heapOff + 268435456 + 65536 + 67108864 + 65536     // heap + op stack + raw arena + exception records
    ph = ph + le8(0) + le8vaddr(0) + le8vaddr(0) + le8(total) + le8(memsz) + le8(65536)

    writeBytes(outFile, eh + ph + body + data)
}

func countStrBytes(ir) {
    let n = toInt(lineCount(ir))
    let i = 0
    let t = 33                              // 32 scratch + 1 newline
    while i < n {
        let ln = getLine(ir, i)
        if isStrPush(ln) == "1" { t = t + (len(quoted(ln)) + 1) }
        i = i + 1
    }
    emit t + ""
}

func le8(v) {
    let out = ""
    let x = v
    let k = 0
    while k < 8 { out = out + hexByte(x % 256)  x = x / 256  k = k + 1 }
    emit out
}

// Emit (0x7F000000 + off) as an 8-byte LE vaddr without holding the full value
// (the backend's own int ceiling is 0x7F000000). byte3 = 0x7F + (off>>24).
func le8vaddr(off) {
    emit hexByte(off % 256) + hexByte((off / 256) % 256) + hexByte((off / 65536) % 256) + hexByte(127 + off / 16777216) + hexByte(0) + hexByte(0) + hexByte(0) + hexByte(0)
}
