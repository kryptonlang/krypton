// A5 fixed-size arrays — array(N) allocates N 8-byte slots (GC buffer); arr[i] /
// arr[i]=v lower to bufGet/SetQwordAt. 64-bit elements (int or pointer). Zero-init.
just run {
    let a = array(5)
    a[0] = 10
    a[1] = 20
    a[2] = a[0] + a[1]
    if a[0] != 10 { print("[FAIL] a0"); exit("1") }
    if a[1] != 20 { print("[FAIL] a1"); exit("1") }
    if a[2] != 30 { print("[FAIL] expr value"); exit("1") }
    let i = 3
    a[i] = 99
    if a[i] != 99 { print("[FAIL] expr index"); exit("1") }
    if a[4] != 0  { print("[FAIL] zero-init"); exit("1") }
    let arr = array(4)
    let j = 0
    while j < 4 { arr[j] = j * j  j += 1 }
    if arr[0] != 0 || arr[1] != 1 || arr[2] != 4 || arr[3] != 9 { print("[FAIL] loop fill"); exit("1") }
    // string elements (pointers)
    let s = array(2)
    s[0] = "hi"
    s[1] = "there"
    if s[0] != "hi" || s[1] != "there" { print("[FAIL] string elems"); exit("1") }
    print("[PASS] fixed-size arrays (int + string elems, expr index/value, zero-init, loop)")
}
