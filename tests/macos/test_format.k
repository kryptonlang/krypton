import "k:format"

just run {
    if zeroPad(7, 4) != "0007" || formatBytes(1536) != "1 KB" || pluralize("item", 3) != "items" {
        print("[FAIL] format regression")
        exit("1")
    }
    if formatHex(255, 4) != "00ff" || formatHex(0, 2) != "00" {
        print("[FAIL] format hex")
        exit("1")
    }
    if formatHex(16, 0) != "10" || formatHex(4096, 0) != "1000" {
        print("[FAIL] numeric hex concatenation")
        exit("1")
    }
    print("[PASS] format helpers")
}
