module objk_process_macos

import "k:objc"

// Argument arrays and returned text live in the caller's autorelease pool.
func okProcessArgs() {
    emit msg(cls("NSMutableArray"), "array")
}

func doProcessArg(args, text) {
    msg_1(args, "addObject:", nsString(text))
    emit args
}

// Result: exit-code text, newline, combined UTF-8 stdout/stderr.
// -1 means launch failure; -2 means output was not valid UTF-8.
func okRunArgvCaptured(executable, args) {
    let task = allocInit("NSTask")
    let pipe = msg(cls("NSPipe"), "pipe")
    let url = msg_1(cls("NSURL"), "fileURLWithPath:", nsString(executable))
    msg_1(task, "setExecutableURL:", url)
    msg_1(task, "setArguments:", args)
    msg_1(task, "setStandardOutput:", pipe)
    msg_1(task, "setStandardError:", pipe)
    msg_1(task, "setStandardInput:", msg(cls("NSFileHandle"), "fileHandleWithNullDevice"))
    if msg_1(task, "launchAndReturnError:", 0) == 0 {
        msg(task, "release")
        emit "-1\nUnable to launch executable"
    }
    // Drain before waiting so a child cannot block on a full output pipe.
    let reader = msg(pipe, "fileHandleForReading")
    let data = msg(reader, "readDataToEndOfFile")
    msg(task, "waitUntilExit")
    let status = msg(task, "terminationStatus")
    let reason = msg(task, "terminationReason")
    if reason == 2 { status = 128 + status }
    let text = msg_2(msg(cls("NSString"), "alloc"), "initWithData:encoding:", data, 4)
    msg(reader, "closeFile")
    msg(task, "release")
    if text == 0 { emit "-2\nProcess output is not UTF-8" }
    let result = status + "\n" + nsToStr(text)
    msg(text, "release")
    emit result
}

// Explicit shell variant: quote arguments when constructing cmd.
func okRunCaptured(cmd) {
    let args = okProcessArgs()
    doProcessArg(args, "-c")
    doProcessArg(args, cmd)
    emit okRunArgvCaptured("/bin/sh", args)
}
