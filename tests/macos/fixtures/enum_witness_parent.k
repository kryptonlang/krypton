import "k:objk_runtime"

func answerFn(runtime, self) { emit 42 }
func writeFn(runtime, self, value) { emit value }
func check(name, expected, actual) {
    if expected != actual { kp("[FAIL] " + name); exit("1") }
    kp("[PASS] " + name)
}

objk protocol Readable {
    require answer() -> int
}

objk protocol Writable extends Readable {
    require write(value: int) -> int
}

objk object Widget conforms Writable {
    method answer() -> int = answerFn
    method write(value: int) -> int = writeFn
}

just run {
    let widget = okKNew(__objkRuntime, Widget)
    check("conformance visible via parent protocol", 1, okKConforms(__objkRuntime, widget, Readable))
    if arg("0") == "--child-slot" { okKSlotSend1(__objkRuntime, widget, Readable, 2, 7); exit(0) }
    if arg("0") == "--child-implementation" { okKWitnessImplementation(__objkRuntime, widget, Readable, 2); exit(0) }
    check("parent witness exposes only parent slots", 1, okKWitnessCount(__objkRuntime, widget, Readable))
    check("child witness exposes inherited and own slots", 2, okKWitnessCount(__objkRuntime, widget, Writable))
    let slot = okKWitnessSlot(__objkRuntime, widget, Readable, 1)
    check("witness slot for parent requirement is set", 1, slot != 0)
    let sent = okKSlotSend(__objkRuntime, widget, Readable, 1)
    check("slot send via parent protocol dispatches", 42, sent)
    doKRelease(__objkRuntime, widget)
}
