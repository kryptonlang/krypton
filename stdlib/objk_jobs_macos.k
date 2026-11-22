// Isolated background processes. No Krypton code runs on worker threads.
// Start/poll/cancel on the owning thread; poll at least every 20-50ms for UI
// jobs. Each child gets a process group, private output files and literal argv.
// Jobs/returned data are Foundation objects; release the job with okJobRelease.
// Timeout is monotonic whole seconds. Output limit is bytes per stream.
module objk_jobs_macos
import "k:objc"
import "head:process_macos"
func _okJobGet(job, key) { emit msg_1(job, "objectForKey:", nsString(key)) }
func _okJobPut(job, key, value) { msg_2(job, "setObject:forKey:", value, nsString(key)); emit 1 }
func _okJobNumber(job, key) { emit msg(_okJobGet(job, key), "longLongValue") }
func _okJobSetNumber(job, key, value) {
    emit _okJobPut(job, key, msg_1(cls("NSNumber"), "numberWithLongLong:", value))
}
func _okJobTime() { emit floatToInt(msg_fp(msg(cls("NSProcessInfo"), "processInfo"), "systemUptime")) }
func _okJobU32(buffer) {
    emit bufGetByte(buffer, 0) + bufGetByte(buffer, 1) * 256 + bufGetByte(buffer, 2) * 65536 + bufGetByte(buffer, 3) * 16777216
}
func _okJobVector(array) {
    let count = msg(array, "count")
    let data = msg_1(cls("NSMutableData"), "dataWithLength:", (count + 1) * 8)
    let bytes = msg(data, "mutableBytes")
    let i = 0
    while i < count {
        bufSetQwordAt(bytes, i * 8, msg(msg_1(array, "objectAtIndex:", i), "UTF8String"))
        i += 1
    }
    emit data
}
func _okJobRead(job, stream) {
    let path = nsToStr(_okJobGet(job, stream))
    let handle = msg_1(cls("NSFileHandle"), "fileHandleForReadingAtPath:", nsString(path))
    if handle == 0 { emit msg(cls("NSData"), "data") }
    let data = msg_1(handle, "readDataOfLength:", _okJobNumber(job, "limit"))
    msg(handle, "closeFile")
    emit data
}
func _okJobFinish(job, status) {
    // Terminate surviving descendants even if the leader exited first.
    let pid = _okJobNumber(job, "pid")
    if pid > 0 { kill(0 - pid, 9) }
    _okJobPut(job, "stdoutData", _okJobRead(job, "stdoutPath"))
    _okJobPut(job, "stderrData", _okJobRead(job, "stderrPath"))
    _okJobSetNumber(job, "status", status)
    _okJobSetNumber(job, "done", 1)
    msg_2(msg(cls("NSFileManager"), "defaultManager"), "removeItemAtPath:error:", _okJobGet(job, "directory"), 0)
    emit 1
}
// args is an NSArray of NSString, excluding argv[0]. No shell interpretation.
// A launch failure returns a completed job with status -1 and errno in error.
func okJobStart(executable, args, cwd, timeoutSeconds, outputLimit) {
    let job = allocInit("NSMutableDictionary")
    _okJobSetNumber(job, "done", 0)
    _okJobSetNumber(job, "status", 0 - 1)
    _okJobSetNumber(job, "pid", 0)
    if timeoutSeconds < 1 || outputLimit < 1 {
        _okJobSetNumber(job, "error", 22)
        _okJobSetNumber(job, "done", 1)
        emit job
    }
    let manager = msg(cls("NSFileManager"), "defaultManager")
    let directory = environ("TMPDIR")
    if directory == "" { directory = "/tmp/" }
    directory = directory + "/krypton-job-" + nsToStr(msg(msg(cls("NSUUID"), "UUID"), "UUIDString"))
    let attrs = msg_2(cls("NSDictionary"), "dictionaryWithObject:forKey:", msg_1(cls("NSNumber"), "numberWithLong:", 448), nsString("NSFilePosixPermissions"))
    if msg_4(manager, "createDirectoryAtPath:withIntermediateDirectories:attributes:error:", nsString(directory), 0, attrs, 0) == 0 {
        _okJobSetNumber(job, "error", 13)
        _okJobSetNumber(job, "done", 1)
        emit job
    }
    _okJobPut(job, "directory", nsString(directory))
    _okJobPut(job, "stdoutPath", nsString(directory + "/stdout"))
    _okJobPut(job, "stderrPath", nsString(directory + "/stderr"))
    _okJobSetNumber(job, "limit", outputLimit)
    _okJobSetNumber(job, "deadline", _okJobTime() + timeoutSeconds)
    let vector = msg(cls("NSMutableArray"), "array")
    msg_1(vector, "addObject:", nsString(executable))
    msg_1(vector, "addObjectsFromArray:", args)
    let argvData = _okJobVector(vector)
    let environment = msg(msg(cls("NSProcessInfo"), "processInfo"), "environment")
    let env = msg(cls("NSMutableArray"), "array")
    let keys = msg(environment, "allKeys")
    let i = 0
    while i < msg(keys, "count") {
        let key = msg_1(keys, "objectAtIndex:", i)
        let entry = nsToStr(key) + "=" + nsToStr(msg_1(environment, "objectForKey:", key))
        msg_1(env, "addObject:", nsString(entry))
        i += 1
    }
    let envData = _okJobVector(env)
    let actions = bufNew(8)
    let attributes = bufNew(8)
    let pidOut = bufNew(8)
    let errorCode = posix_spawn_file_actions_init(actions)
    let actionsReady = errorCode == 0
    let attributesReady = 0
    if errorCode == 0 {
        errorCode = posix_spawnattr_init(attributes)
        attributesReady = errorCode == 0
    }
    if errorCode == 0 { errorCode = posix_spawnattr_setflags(attributes, 2) }
    if errorCode == 0 { errorCode = posix_spawnattr_setpgroup(attributes, 0) }
    if errorCode == 0 { errorCode = posix_spawn_file_actions_addopen(actions, 0, "/dev/null", 0, 0) }
    if errorCode == 0 { errorCode = posix_spawn_file_actions_addopen(actions, 1, msg(_okJobGet(job, "stdoutPath"), "UTF8String"), 1537, 384) }
    if errorCode == 0 { errorCode = posix_spawn_file_actions_addopen(actions, 2, msg(_okJobGet(job, "stderrPath"), "UTF8String"), 1537, 384) }
    if errorCode == 0 && cwd != "" { errorCode = posix_spawn_file_actions_addchdir_np(actions, cwd) }
    if errorCode == 0 { errorCode = posix_spawn(pidOut, executable, actions, attributes, msg(argvData, "bytes"), msg(envData, "bytes")) }
    if attributesReady { posix_spawnattr_destroy(attributes) }
    if actionsReady { posix_spawn_file_actions_destroy(actions) }
    _okJobSetNumber(job, "error", errorCode)
    if errorCode != 0 { _okJobFinish(job, 0 - 1); emit job }
    _okJobSetNumber(job, "pid", _okJobU32(pidOut))
    emit job
}
func okJobCancel(job) {
    if _okJobNumber(job, "done") != 0 { emit 0 }
    _okJobSetNumber(job, "cancelled", 1)
    kill(0 - _okJobNumber(job, "pid"), 9)
    emit 1
}
// Poll returns 1 when complete, 0 while running. Never waits for child exit.
func okJobPoll(job) {
    if _okJobNumber(job, "done") != 0 { emit 1 }
    if _okJobTime() >= _okJobNumber(job, "deadline") {
        _okJobSetNumber(job, "timedOut", 1)
        okJobCancel(job)
    }
    let manager = msg(cls("NSFileManager"), "defaultManager")
    let outAttrs = msg_2(manager, "attributesOfItemAtPath:error:", _okJobGet(job, "stdoutPath"), 0)
    let errAttrs = msg_2(manager, "attributesOfItemAtPath:error:", _okJobGet(job, "stderrPath"), 0)
    let outSize = msg(msg_1(outAttrs, "objectForKey:", nsString("NSFileSize")), "longLongValue")
    let errSize = msg(msg_1(errAttrs, "objectForKey:", nsString("NSFileSize")), "longLongValue")
    _okJobSetNumber(job, "outputBytes", outSize + errSize)
    if outSize > _okJobNumber(job, "limit") || errSize > _okJobNumber(job, "limit") {
        _okJobSetNumber(job, "truncated", 1)
        okJobCancel(job)
    }
    let statusOut = bufNew(8)
    let result = waitpid(_okJobNumber(job, "pid"), statusOut, 1)
    if result == 0 { emit 0 }
    if result < 0 { _okJobFinish(job, 0 - 1); emit 1 }
    let raw = _okJobU32(statusOut)
    let signal = raw - raw / 128 * 128
    let status = raw / 256 - raw / 65536 * 256
    if signal != 0 { status = 128 + signal }
    _okJobFinish(job, status)
    emit 1
}
func okJobStatus(job) { emit _okJobNumber(job, "status") }
func okJobFlag(job, key) { emit _okJobNumber(job, key) }
// Borrowed NSData, valid until job release. Supports embedded NUL / non-UTF8.
func okJobOutputData(job, stderrStream) {
    if stderrStream != 0 { emit _okJobGet(job, "stderrData") }
    emit _okJobGet(job, "stdoutData")
}
func okJobOutputText(job, stderrStream) {
    let data = okJobOutputData(job, stderrStream)
    let text = msg_2(msg(cls("NSString"), "alloc"), "initWithData:encoding:", data, 4)
    if text == 0 { _okJobSetNumber(job, "invalidUTF8", 1); emit "" }
    let borrowed = nsToStr(text)
    let result = substring(borrowed, 0, len(borrowed))
    msg(text, "release")
    emit result
}
// CLI convenience only: do not block the UI thread with this function.
func okJobWait(job) {
    while !okJobPoll(job) { usleep(20000) }
    emit okJobStatus(job)
}
// A running job must be cancelled and reaped before release. Refuse rather than
// silently leave an orphan. Return 0 when caller must keep polling.
func okJobRelease(job) {
    if !okJobPoll(job) { okJobCancel(job); emit 0 }
    msg(job, "release")
    emit 1
}
