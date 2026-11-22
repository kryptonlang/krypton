// macOS 3.0 contract: sbToString returns independently owned text.
let savedBuilderText = ""
func snapshotCheck(value, message) {
    if value == 0 { print("FAIL " + message); exit(1) }
    print("PASS " + message)
}
func snapshotFromTemporaryBuilder() {
    let builder = sbNew()
    sbAppend(builder, "original pane records")
    emit sbToString(builder)
}
func snapshotChurn() {
    let i = 0
    while i < 500 {
        let builder = sbNew()
        sbAppend(builder, "overwritten")
        i += 1
    }
}
just run {
    savedBuilderText = snapshotFromTemporaryBuilder()
    gcCollect()
    snapshotChurn()
    snapshotCheck(savedBuilderText == "original pane records", "global snapshot survives collector and reuse")
    let builder = sbNew()
    let emptyText = sbToString(builder)
    sbAppend(builder, "first")
    let firstText = sbToString(builder)
    sbAppend(builder, " second")
    snapshotCheck(emptyText == "", "empty snapshot remains empty")
    snapshotCheck(firstText == "first", "append does not mutate earlier snapshot")
    snapshotCheck(sbToString(builder) == "first second", "builder still appends")
    let i = 0
    while i < 1000 { sbAppend(builder, "x"); i += 1 }
    snapshotCheck(firstText == "first", "growth does not invalidate snapshot")
    gcCollect()
    snapshotChurn()
    snapshotCheck(firstText == "first", "local snapshot survives collection")
}
