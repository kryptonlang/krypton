// Pure Krypton libobjk runtime smoke test on Linux.
import "k:objk_runtime"

func smokeFn() { emit 0 }

just run {
    let rt = okKRuntime(4096)
    let obj = okKAllocate(rt, 32)
    okKWrite(rt, obj, 0, 42)
    if okKRead(rt, obj, 0) != 42 { print("[FAIL] objk read/write")  exit(1) }
    let text = okKText(rt, "linux-aarch64")
    if okKTextEquals(rt, text, "linux-aarch64") != 1 { print("[FAIL] objk text")  exit(1) }
    let klass = okKClass(rt, "Smoke", 0)
    okKMethod(rt, klass, "value", 0, funcptr(smokeFn))
    doKRegister(rt, klass)
    let instance = okKNew(rt, klass)
    if okKAlive(rt, instance) == 0 { print("[FAIL] objk object")  exit(1) }
    print("[PASS] Linux libobjk runtime")
}
