// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// Testing framework for Krypton
// Provides structured test execution

module test_framework


// Run a single test case
func runTest(name, expected, actual) {
    if expected == actual {
        print("[PASS] " + name)
        emit 1
    } else {
        print("[FAIL] " + name)
        print("       Expected: " + expected)
        print("       Actual:   " + actual)
        emit 0
    }
}

// Print test suite header
func suiteHeader(suiteName) {
    print("")
    print("================================")
    print("  Test Suite: " + suiteName)
    print("================================")
}

// Print test suite footer with summary
func suiteFooter(suiteName, passed, total) {
    print("--------------------------------")
    print("  " + suiteName + ": " + passed + "/" + total + " passed")
    if passed == total {
        print("  Status: ALL PASSED")
    } else {
        print("  Status: FAILURES DETECTED")
    }
    print("================================")
    print("")
}

// Print a test separator
func separator() {
    print("--------------------------------")
}

// Assert not equal
func assertNotEqual(name, a, b) {
    if a != b {
        print("[PASS] " + name)
        emit 1
    } else {
        print("[FAIL] " + name)
        print("       Values should differ: " + a)
        emit 0
    }
}

// Assert numeric range
func assertInRange(name, val, lo, hi) {
    let v = toInt(val)
    if v >= lo {
        if v <= hi {
            print("[PASS] " + name)
            emit 1
        }
    }
    print("[FAIL] " + name)
    print("       " + val + " not in range [" + lo + ", " + hi + "]")
    emit 0
}

// Print final report across all suites
func finalReport(totalPassed, totalFailed) {
    print("")
    print("########################################")
    print("#         FINAL TEST REPORT            #")
    print("########################################")
    print("# Total Passed: " + totalPassed)
    print("# Total Failed: " + totalFailed)
    print("# Grand Total:  " + (totalPassed + totalFailed))
    if totalFailed == 0 {
        print("# Result: SUCCESS")
    } else {
        print("# Result: FAILURE")
    }
    print("########################################")
}

// ── More assertion helpers ───────────────────────────────────────────

func assertContains(name, haystack, needle) {
    if indexOf(haystack, needle) >= 0 {
        print("[PASS] " + name)
        emit 1
    }
    print("[FAIL] " + name)
    print("       haystack: " + haystack)
    print("       needle:   " + needle)
    emit 0
}

func assertGreater(name, a, b) {
    if toInt(a) > toInt(b) {
        print("[PASS] " + name)
        emit 1
    }
    print("[FAIL] " + name)
    print("       " + a + " not > " + b)
    emit 0
}

func assertLess(name, a, b) {
    if toInt(a) < toInt(b) {
        print("[PASS] " + name)
        emit 1
    }
    print("[FAIL] " + name)
    print("       " + a + " not < " + b)
    emit 0
}

func assertTruthy(name, val) {
    if isTruthy(val) {
        print("[PASS] " + name)
        emit 1
    }
    print("[FAIL] " + name + " — expected truthy, got: " + val)
    emit 0
}

func assertFalsy(name, val) {
    if isTruthy(val) {
        print("[FAIL] " + name + " — expected falsy, got: " + val)
        emit 0
    }
    print("[PASS] " + name)
    emit 1
}

// Skip a test (logged, not counted as fail).
func skipTest(name, reason) {
    print("[SKIP] " + name + " — " + reason)
    emit 1
}

// Mark a test pending (visible in output).
func todoTest(name) {
    print("[TODO] " + name)
    emit 1
}
