import "k:format"
just run {
    if toInt(-15) != -15 { print("[FAIL] negative integer conversion"); exit(1) }
    if -(-15) != 15 { print("[FAIL] double negative integer"); exit(1) }
    if toInt("-15") != -15 { print("[FAIL] negative decimal text"); exit(1) }
    if fromCharCode("65") != "A" || fromCharCode(65) != "A" {
        print("[FAIL] text/integer character code"); exit(1)
    }
    if formatHex(-15, 4) != "" { print("[FAIL] negative hex must reject"); exit(1) }
    print("[PASS] signed conversion and invalid hex guard")
}
