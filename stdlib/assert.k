// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// Assertion and testing helpers for Krypton

module assert


// Assert two values are equal
func assertEqual(actual, expected, msg) {
    if actual != expected {
        print("FAIL: " + msg)
        print("  expected: " + expected)
        print("  actual:   " + actual)
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

// Assert a value is truthy
func assertTrue(val, msg) {
    if val {
        print("PASS: " + msg)
        emit 1
    }
    print("FAIL: " + msg)
    print("  expected truthy, got: " + val)
    emit 0
}

// Assert a value is falsy
func assertFalse(val, msg) {
    if val {
        print("FAIL: " + msg)
        print("  expected falsy, got: " + val)
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

// Assert value is greater than expected
func assertGreater(actual, expected, msg) {
    if toInt(actual) > toInt(expected) {
        print("PASS: " + msg)
        emit 1
    }
    print("FAIL: " + msg)
    print("  expected " + actual + " > " + expected)
    emit 0
}

// Assert value is less than expected
func assertLess(actual, expected, msg) {
    if toInt(actual) < toInt(expected) {
        print("PASS: " + msg)
        emit 1
    }
    print("FAIL: " + msg)
    print("  expected " + actual + " < " + expected)
    emit 0
}

// Assert string starts with prefix
func assertStartsWith(s, prefix, msg) {
    if startsWith(s, prefix) {
        print("PASS: " + msg)
        emit 1
    }
    print("FAIL: " + msg)
    print("  expected '" + s + "' to start with '" + prefix + "'")
    emit 0
}

// Assert string length equals expected
func assertLength(s, expected, msg) {
    if len(s) == expected {
        print("PASS: " + msg)
        emit 1
    }
    print("FAIL: " + msg)
    print("  expected length " + expected + ", got " + len(s))
    emit 0
}

// Run a test suite and report results
func reportResults(passed, failed) {
    print("")
    print("========================")
    print("Test Results")
    print("========================")
    print("Passed: " + passed)
    print("Failed: " + failed)
    print("Total:  " + (passed + failed))
    if failed == 0 {
        print("ALL TESTS PASSED")
    } else {
        print("SOME TESTS FAILED")
    }
    print("========================")
}

// ── Inequality / containment / emptiness ─────────────────────────────

func assertNotEqual(actual, expected, msg) {
    if actual == expected {
        print("FAIL: " + msg)
        print("  expected NOT: " + expected)
        print("  got:          " + actual)
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

func assertContains(s, sub, msg) {
    if indexOf(s, sub) < 0 {
        print("FAIL: " + msg)
        print("  haystack: " + s)
        print("  needle:   " + sub)
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

func assertEndsWith(s, suffix, msg) {
    if endsWith(s, suffix) == "0" {
        print("FAIL: " + msg)
        print("  string:   " + s)
        print("  expected suffix: " + suffix)
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

func assertEmpty(s, msg) {
    if len(s) != 0 {
        print("FAIL: " + msg)
        print("  expected empty, got: " + s)
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

func assertNotEmpty(s, msg) {
    if len(s) == 0 {
        print("FAIL: " + msg)
        print("  expected non-empty")
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

// ── Numeric ranges ───────────────────────────────────────────────────

func assertInRange(n, lo, hi, msg) {
    let v = toInt(n)
    if v < lo || v > hi {
        print("FAIL: " + msg)
        print("  value: " + n)
        print("  range: [" + lo + ", " + hi + "]")
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

func assertGreaterEqual(actual, expected, msg) {
    if toInt(actual) < toInt(expected) {
        print("FAIL: " + msg)
        print("  actual:   " + actual)
        print("  expected >= " + expected)
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}

func assertLessEqual(actual, expected, msg) {
    if toInt(actual) > toInt(expected) {
        print("FAIL: " + msg)
        print("  actual:   " + actual)
        print("  expected <= " + expected)
        emit 0
    }
    print("PASS: " + msg)
    emit 1
}
