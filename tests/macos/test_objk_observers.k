import "k:objk_runtime"

let gFires = 0
let gOld = 0
let gNew = 0
let gClassFires = 0
let gDerivedFires = 0
let gNoteFires = 0
let gBindFires = 0
let gMultiFires = 0
let gAfterRelease = 0
let gPinnedChild = 0

func hookScore(runtime, self, name, old, new) {
    gFires += 1
    gOld = old
    gNew = new
    // Re-entrant: writing another field fires its observers too.
    if new == 123 { doKSet(runtime, self, "note", 7) }
    emit 0
}
func hookNote(runtime, self, name, old, new) {
    gNoteFires += 1
    emit 0
}
func hookClass(runtime, self, name, old, new) {
    gClassFires += 1
    emit 0
}
func hookDerived(runtime, self, name, old, new) {
    gDerivedFires += 1
    emit 0
}
func hookBound(runtime, self, name, old, new) {
    gBindFires += 1
    emit 0
}
func hookMultiA(runtime, self, name, old, new) { gMultiFires += 1; emit 0 }
func hookMultiB(runtime, self, name, old, new) { gMultiFires += 10; emit 0 }
func hookText(runtime, self, name, old, new) {
    gFires += 1
    gNew = new
    emit 0
}

func releaseReceiver(runtime, self, name, old, new) {
    doKRelease(runtime, self)
    emit 0
}

func readAfterRelease(runtime, self, name, old, new) {
    check("observer receives an arena field-name handle", "finish", okKTextValue(runtime, name))
    gAfterRelease = okKGet(runtime, self, "finish")
    emit 0
}

func clearOwnedDuringNotification(runtime, self, name, old, new) {
    if new != 0 {
        doKRelease(runtime, new)
        doKOwn(runtime, self, "owned", 0)
    }
    emit 0
}

func readPinnedChild(runtime, self, name, old, new) {
    if new != 0 { gPinnedChild = okKGet(runtime, new, "score") }
    emit 0
}

func check(name, expected, actual) {
    if expected != actual { print("[FAIL] " + name); exit("1") }
    print("[PASS] " + name)
}

just run {
    let runtime = okKRuntime(8192)
    let meterClass = okKClass(runtime, "Meter", 0)
    doKRegister(runtime, meterClass)
    let derivedClass = okKClass(runtime, "DerivedMeter", meterClass)
    doKRegister(runtime, derivedClass)

    let obj = okKNew(runtime, meterClass)
    doKSet(runtime, obj, "score", 41)
    doKObserve(runtime, obj, "score", funcptr(hookScore))
    doKSet(runtime, obj, "score", 42)
    check("instance observer fires", 1, gFires)
    check("old value passed", 41, gOld)
    check("new value passed", 42, gNew)
    doKSet(runtime, obj, "score", 43)
    check("fires again", 2, gFires)
    check("second old value", 42, gOld)

    doKObserve(runtime, obj, "note", funcptr(hookNote))
    doKSet(runtime, obj, "note", 9)
    check("other field fires its own observers", 1, gNoteFires)
    check("note write does not touch score observer", 2, gFires)

    doKSet(runtime, obj, "score", 123)
    check("re-entrant observer fires nested observers", 2, gNoteFires)
    check("re-entrant write counted", 3, gFires)

    let other = okKNew(runtime, meterClass)
    doKSet(runtime, other, "score", 7)
    check("instance observer does not leak into other instance", 3, gFires)

    okBind(runtime, other, "score", funcptr(hookBound))
    doKSet(runtime, other, "score", 8)
    check("okBind-style alias registers an instance observer", 1, gBindFires)
    doKRelease(runtime, other)

    doKClassObserve(runtime, meterClass, "score", funcptr(hookClass))
    doKClassObserve(runtime, derivedClass, "score", funcptr(hookDerived))
    let derived = okKNew(runtime, derivedClass)
    let base = okKNew(runtime, meterClass)
    doKSet(runtime, derived, "score", 1)
    check("class observer fires for subclass instance", 1, gClassFires)
    check("derived class observer fires for subclass", 1, gDerivedFires)
    doKSet(runtime, base, "score", 1)
    check("class observer fires for base instance", 2, gClassFires)
    check("derived observer does not fire for base instance", 1, gDerivedFires)

    doKObserve(runtime, base, "score", funcptr(hookMultiA))
    doKObserve(runtime, base, "score", funcptr(hookMultiB))
    doKSet(runtime, base, "score", 2)
    check("multiple observers on one field all fire", 11, gMultiFires)

    let txt = okKNew(runtime, meterClass)
    doKObserve(runtime, txt, "label", funcptr(hookText))
    gFires = 0
    let t1 = okKText(runtime, "first")
    doKText(runtime, txt, "label", t1)
    doKReleaseText(runtime, t1)
    check("text field fires observer", 1, gFires)
    check("text observer sees new handle value", okKTextValue(runtime, gNew), "first")

    let child = okKNew(runtime, meterClass)
    let parent = okKNew(runtime, meterClass)
    doKObserve(runtime, parent, "child", funcptr(hookScore))
    gOld = 0
    gNew = 0
    gFires = 0
    doKOwn(runtime, parent, "child", child)
    check("owned write fires observer", 1, gFires)
    check("owned observer sees child handle", child, gNew)

    let finishing = okKNew(runtime, meterClass)
    doKObserve(runtime, finishing, "finish", funcptr(readAfterRelease))
    doKObserve(runtime, finishing, "finish", funcptr(releaseReceiver))
    doKSet(runtime, finishing, "finish", 17)
    check("later observers can read the retained receiver", 17, gAfterRelease)
    check("receiver is released after notification", 0, okKRefCount(runtime, finishing))

    let replaced = okKNew(runtime, meterClass)
    doKSet(runtime, replaced, "score", 23)
    doKObserve(runtime, parent, "owned", funcptr(readPinnedChild))
    doKObserve(runtime, parent, "owned", funcptr(clearOwnedDuringNotification))
    doKOwn(runtime, parent, "owned", replaced)
    check("outer notification retains a replaced owned value", 23, gPinnedChild)
    check("nested write replaces the field", 0, okKGet(runtime, parent, "owned"))
    check("owned value is released after notification", 0, okKRefCount(runtime, replaced))

    doKRelease(runtime, obj)
    doKRelease(runtime, derived)
    doKRelease(runtime, base)
    doKRelease(runtime, txt)
    doKRelease(runtime, child)
    doKRelease(runtime, parent)
    print("[PASS] observers (set/own/text/class/multi/re-entrant/alias)")
}
