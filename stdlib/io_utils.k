// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// I/O utility functions for Krypton
// File reading and output helpers

module io_utils


// Read a file and return its content
func readFileContent(path) {
    emit readFile(path)
}

// Get a specific line from file contents
func getFileLine(content, lineNum) {
    emit getLine(content, lineNum)
}

// Count the number of lines in file contents
func countFileLines(content) {
    emit lineCount(content)
}

// Print a line with a prefix
func printWithPrefix(prefix, msg) {
    print(prefix + msg)
}

// Print an error message
func printError(msg) {
    print("[ERROR] " + msg)
}

// Print a warning message
func printWarning(msg) {
    print("[WARN]  " + msg)
}

// Print an info message
func printInfo(msg) {
    print("[INFO]  " + msg)
}

// Print a debug message
func printDebug(msg) {
    print("[DEBUG] " + msg)
}

// Print a numbered list from a comma-separated list
func printNumbered(list) {
    let size = count(list)
    let i = 0
    while i < size {
        let num = i + 1
        print("" + num + ". " + split(list, i))
        i += 1
    }
}

// Print a section header
func printHeader(title) {
    let line = ""
    let i = 0
    while i < len(title) + 4 {
        line = line + "="
        i += 1
    }
    print(line)
    print("  " + title)
    print(line)
}

// Print a blank line
func printBlank() {
    print("")
}

// Read command line argument with default
func argOrDefault(idx, defaultVal) {
    if idx < argCount() {
        emit arg(idx)
    }
    emit defaultVal
}

// Print all command line arguments
func printArgs() {
    let i = 0
    while i < argCount() {
        print("arg[" + i + "] = " + arg(i))
        i += 1
    }
}
