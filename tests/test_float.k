// A1 floating point — boxed-f64 arithmetic + comparisons (macOS arm64).
//
// Representation: a float is a pointer to an 8-byte f64 box (literals via runtime
// M/scale materialization; results via an 8-byte GC alloc). Float builtins know
// their operands are floats statically, so no runtime type tag — and they
// auto-promote int operands (value < 1<<32 → scvtf), e.g. fadd(5, 2.5).
//
// Printing (fformat) lands in F2; until then values are validated via feq/flt/fgt.
// macOS-only: the fp builtins have macho codegen; the ELF/PE backends don't
// implement them yet. build.sh skips this off macOS.
just run {
    if feq(fadd(1.5, 2.25), 3.75) == 0 { print("[FAIL] fadd"); exit("1") }
    if feq(fsub(5.0, 1.25), 3.75) == 0 { print("[FAIL] fsub"); exit("1") }
    if feq(fmul(2.5, 4.0), 10.0)  == 0 { print("[FAIL] fmul"); exit("1") }
    if feq(fdiv(9.0, 2.0), 4.5)   == 0 { print("[FAIL] fdiv"); exit("1") }
    if flt(1.5, 2.25)             == 0 { print("[FAIL] flt"); exit("1") }
    if fgt(2.25, 1.5)             == 0 { print("[FAIL] fgt"); exit("1") }
    if feq(ffloor(3.7), 3.0)      == 0 { print("[FAIL] ffloor"); exit("1") }
    if feq(fceil(3.2), 4.0)       == 0 { print("[FAIL] fceil"); exit("1") }
    if feq(fround(3.5), 4.0)      == 0 { print("[FAIL] fround"); exit("1") }
    if feq(fadd(5, 2.5), 7.5)     == 0 { print("[FAIL] int-promote"); exit("1") }
    // fformat (F2): double -> decimal string.
    if fformat(3.14159, 2)        != "3.14"     { print("[FAIL] fformat round-down"); exit("1") }
    if fformat(3.14159, 4)        != "3.1416"   { print("[FAIL] fformat round-up"); exit("1") }
    if fformat(0.05, 2)           != "0.05"     { print("[FAIL] fformat leading-zero frac"); exit("1") }
    if fformat(0.0, 2)            != "0.00"     { print("[FAIL] fformat zero"); exit("1") }
    if fformat(10.0, 0)           != "10"       { print("[FAIL] fformat prec0"); exit("1") }
    if fformat(-3.14, 2)          != "-3.14"    { print("[FAIL] fformat negative"); exit("1") }
    if fformat(fdiv(1.0, 3.0), 6) != "0.333333" { print("[FAIL] fformat repeating"); exit("1") }
    // f64 OPERATORS (FE static type inference): arithmetic + comparisons on
    // f64-typed locals + float literals, instead of the explicit fadd/.../flt
    // builtins. Int operands auto-promote.
    let a: f64 = 3.0
    let b: f64 = 2.0
    if fformat(a * b, 2)       != "6.00"  { print("[FAIL] op *"); exit("1") }
    if fformat(a + b, 2)       != "5.00"  { print("[FAIL] op +"); exit("1") }
    if fformat(a - b, 2)       != "1.00"  { print("[FAIL] op -"); exit("1") }
    if fformat(a / b, 2)       != "1.50"  { print("[FAIL] op /"); exit("1") }
    if fformat(a * 2.0, 2)     != "6.00"  { print("[FAIL] op var*lit"); exit("1") }
    if fformat((a + b) * 2.0, 2) != "10.00" { print("[FAIL] op nested"); exit("1") }
    if fformat(a * 2 + 1.5, 2) != "7.50"  { print("[FAIL] op int-promote"); exit("1") }
    if a > b == 0  { print("[FAIL] op >"); exit("1") }
    if b < a == 0  { print("[FAIL] op <"); exit("1") }
    if a >= 3.0 == 0 { print("[FAIL] op >="); exit("1") }
    if a == 3.0 == 0 { print("[FAIL] op =="); exit("1") }
    if a != b == 0 { print("[FAIL] op !="); exit("1") }
    // int <-> float conversions.
    if fformat(intToFloat(5), 2)  != "5.00" { print("[FAIL] intToFloat"); exit("1") }
    if floatToInt(3.7)            != 3      { print("[FAIL] floatToInt trunc"); exit("1") }
    if floatToInt(fmul(2.5, 4.0)) != 10     { print("[FAIL] floatToInt expr"); exit("1") }
    if fformat(intToFloat(10) / 4.0, 2) != "2.50" { print("[FAIL] int->float in op"); exit("1") }
    // A7: float compound assignment (typed f64 target + untyped via rhs literal).
    let c: f64 = 3.0
    c += 1.5  if fformat(c, 1) != "4.5" { print("[FAIL] f +="); exit("1") }
    c *= 2.0  if fformat(c, 1) != "9.0" { print("[FAIL] f *="); exit("1") }
    c -= 1.0  if fformat(c, 1) != "8.0" { print("[FAIL] f -="); exit("1") }
    c /= 2.0  if fformat(c, 1) != "4.0" { print("[FAIL] f /="); exit("1") }
    c++       if fformat(c, 1) != "5.0" { print("[FAIL] f ++"); exit("1") }
    let d = 1.0
    d += 0.5  if fformat(d, 1) != "1.5" { print("[FAIL] untyped f += (rhs-typed)"); exit("1") }
    print("[PASS] float arith + compares + fformat + operators + conv + compound (boxed f64)")
}
