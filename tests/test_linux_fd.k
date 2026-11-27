// Linux aarch64/x86 native fd + shared-mapping smoke test.
just run {
    let fd = memfdCreate(4096)
    if fd < 0 { print("[FAIL] memfdCreate")  exit(1) }
    if fdSetNonblock(fd) != 0 { print("[FAIL] fdSetNonblock")  exit(1) }
    if fdWrite(fd, "abc", 3) != 3 { print("[FAIL] fdWrite")  exit(1) }
    let map = mmapShared(fd, 4096)
    if bufGetByte(map, 0) != 97 || bufGetByte(map, 1) != 98 || bufGetByte(map, 2) != 99 {
        print("[FAIL] mmap readback")  exit(1)
    }
    bufSetByte(map, 3, 100)
    if bufGetByte(map, 3) != 100 { print("[FAIL] mmap writeback")  exit(1) }
    if fdClose(fd) != 0 { print("[FAIL] fdClose")  exit(1) }
    print("[PASS] Linux fd + mmap")
}
