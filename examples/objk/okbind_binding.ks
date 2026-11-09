#!/usr/bin/env kr

import "k:okui"
import "k:objk_runtime_macos"
import "k:choc_macos"

let bindRuntime = okKRuntime(65536)
let bindModel = 0
let boundLabel = 0

func bindModelValue(runtime, self) {
    if !okKHas(runtime, self, "value") { emit 0 }
    emit okKGet(runtime, self, "value")
}
func bindModelIncrement(runtime, self) {
    emit doKSet(runtime, self, "value", bindModelValue(runtime, self) + 1)
}
func makeBindModelClass(runtime) {
    let cls = okKClass(runtime, "BindCounter", 0)
    okKMethod(runtime, cls, "value", 0, funcptr(bindModelValue))
    okKMethod(runtime, cls, "increment", 0, funcptr(bindModelIncrement))
    emit doKRegister(runtime, cls)
}

// didSet hook: fires after every committed write to "value".
// Swift's didSet/binding boilerplate, via the observer funnel.
func bindValueDidSet(runtime, self, name, old, new) {
    if boundLabel != 0 {
        doText(boundLabel, "" + new)
        // Native invalidation; exercises the setNeedsDisplay path a
        // custom-view redraw would need. Native labels self-update.
        chocNeedsDisplay(boundLabel)
    }
    emit 0
}

func onIncrement(self, cmd, sender) {
    okKSend(bindRuntime, bindModel, "increment")
    emit done()
}

just run {
    app("Objective-K Binding")
    let win = window("Objective-K Binding", 360, 220)
    boundLabel = label(win, "0", okRect(24, 110, 300, 32))
    let incrementButton = button(win, "Increment", okRect(24, 40, 140, 32))
    doClick(incrementButton, "bind.increment", funcptr(onIncrement))

    let cls = makeBindModelClass(bindRuntime)
    bindModel = okKNew(bindRuntime, cls)
    doKSet(bindRuntime, bindModel, "value", 0)
    okBind(bindRuntime, bindModel, "value", funcptr(bindValueDidSet))

    if arg("0") == "--smoke" {
        msg_1(incrementButton, "performClick:", 0)
        msg_1(incrementButton, "performClick:", 0)
        if okKSend(bindRuntime, bindModel, "value") != 2 {
            kp("[FAIL] okBind binding did not propagate")
            exit("1")
        }
        if text(boundLabel) != "2" {
            kp("[FAIL] bound label did not update")
            exit("1")
        }
        doKRelease(bindRuntime, bindModel)
        kp("[PASS] okBind binding smoke")
        exit("0")
    }

    doShow(win)
    doRun()
}
