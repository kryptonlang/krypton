objk protocol StaticIdentified { require identifier() -> int }
objk object StaticBase conforms StaticIdentified {
    method identifier() -> int = objectIdentifier
}
objk object StaticChild extends StaticBase { }
objk object StaticCounter {
    method add(value: int) -> int = addValue
    method label() -> text = labelValue
    method make() -> StaticIdentified = makeChild
}
func objectIdentifier(runtime, self) { emit 7 }
func makeChild(runtime, self) { emit okKNew(runtime, StaticChild) }
func addValue(runtime, self, value: int) -> int {
    let next: int = value
    next = 42
    emit next
}
func labelValue(runtime, self) {
    emit okKText(runtime, "checked")
}
just run {
    let object = okKNew(__objkRuntime, StaticCounter)
    if okKSend1(__objkRuntime, object, "add", 1) != 42 { print("[FAIL] static integer"); exit(1) }
    let text = okKSend(__objkRuntime, object, "label")
    if okKTextValue(__objkRuntime, text) != "checked" { print("[FAIL] static text"); exit(1) }
    doKReleaseText(__objkRuntime, text)
    let child = okKSend(__objkRuntime, object, "make")
    if okKSend(__objkRuntime, child, "identifier") != 7 { print("[FAIL] static conformance"); exit(1) }
    doKRelease(__objkRuntime, child)
    doKRelease(__objkRuntime, object)
    print("[PASS] Objective-K static callback types")
}
