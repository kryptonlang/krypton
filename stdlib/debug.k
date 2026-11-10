// Debugging utilities for Krypton
// Helpers for inspecting program state

module debug


// Print a value with label
func inspect(label, val) {
    print("[INSPECT] " + label + " = " + val)
}

// Print the type and length info of a value
func inspectDetail(label, val) {
    print("[INSPECT] " + label)
    print("  value:  " + val)
    print("  length: " + len(val))
}

// Print a hexdump-style view of first n chars
func hexView(s, n) {
    let limit = n
    if limit > len(s) {
        limit = len(s)
    }
    print("HexView (first " + limit + " chars):")
    let i = 0
    while i < limit {
        let ch = s[i]
        print("  [" + i + "] '" + ch + "'")
        i += 1
    }
}

// Print a separator line for debug output
func debugSep(label) {
    print("=== DEBUG: " + label + " ===")
}

// Trace function entry
func traceEnter(funcName) {
    print(">> ENTER " + funcName)
}

// Trace function exit
func traceExit(funcName, result) {
    print("<< EXIT  " + funcName + " => " + result)
}

// Assert with abort message
func assertOrDie(condition, msg) {
    if condition == 0 {
        print("ASSERTION FAILED: " + msg)
        emit "ABORT"
    }
}

// Print a list with indices
func dumpList(label, list) {
    print("[DUMP] " + label + ":")
    let size = count(list)
    let i = 0
    while i < size {
        print("  [" + i + "] = " + split(list, i))
        i += 1
    }
    print("  (size: " + size + ")")
}

// Print lines with line numbers
func dumpLines(label, text) {
    print("[DUMP] " + label + ":")
    let lines = lineCount(text)
    let i = 0
    while i < lines {
        let num = i + 1
        print("  " + num + ": " + getLine(text, i))
        i += 1
    }
    print("  (lines: " + lines + ")")
}

// Log a timestamped message (using a counter)
func log(counter, msg) {
    print("[LOG " + counter + "] " + msg)
    emit counter + 1
}

// ── Quick cycle-stamp helpers (closure-free, since callPtr is fragile) ──

// Stamp now; pair with elapsedCycles(stamp) below.
func stampCycles() { emit rdtsc() }

// Cycles since `stamp`. Use around any code:
//   let t = stampCycles()
//   ... work ...
//   print("ran in " + elapsedCycles(t) + " cycles")
func elapsedCycles(stamp) {
    emit rdtsc() - toInt(stamp + "")
}
