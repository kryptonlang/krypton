// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// stdlib/io.k -- Human-facing input helpers.

module io

func scan(prompt) {
    emit readLine(prompt)
}

// Contract: native backends should lower get() to one key read with no Enter
// and no echo. This fallback keeps the source-level API usable today.
func get() {
    let line = readLine()
    if len(line) == 0 { emit "" }
    emit substring(line, 0, 1)
}

// Contract: native backends should echo the key as it is read.
func getEcho() {
    emit get()
}