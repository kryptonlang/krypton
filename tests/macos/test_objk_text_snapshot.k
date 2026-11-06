import "k:objk"

let retainedBuilderText = ""
let retainedObjectText = ""

func snapshotBuilder() {
    let builder = sbNew()
    sbAppend(builder, "original pane records")
    emit okCopyText(sbToString(builder))
}

func snapshotObject() {
    let pool = newPool()
    let snapshot = okObjectText(nsString("object text after pool drain"))
    drainPool(pool)
    emit snapshot
}

just run {
    retainedBuilderText = snapshotBuilder()
    retainedObjectText = snapshotObject()
    gcCollect()
    let i = 0
    while i < 200 {
        let builder = sbNew()
        sbAppend(builder, "overwritten")
        i = i + 1
    }
    if retainedBuilderText != "original pane records" || retainedObjectText != "object text after pool drain" {
        print("[FAIL] retained text snapshot")
        exit(1)
    }
    if okCopyText("") != "" || okObjectText(0) != "" {
        print("[FAIL] empty text snapshot")
        exit(1)
    }
    print("[PASS] Objective-K text snapshots survive collection and pool drain")
}
