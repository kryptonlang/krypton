import "k:objc"
import "k:objk_collections_macos"
func collectionCheck(value, message) {
    if value == 0 { print("FAIL " + message); exit(1) }
    print("PASS " + message)
}
just run {
    let pool = newPool()
    let items = okTextListNew()
    okTextListAdd(items, "")
    okTextListAdd(items, "comma,tab\tline\npipe|semicolon;雪")
    okTextListAdd(items, "last")
    collectionCheck(okCollectionCount(items) == 3, "lossless count")
    collectionCheck(okTextListAt(items, 0) == "", "stored empty text")
    collectionCheck(okTextListAt(items, 1) == "comma,tab\tline\npipe|semicolon;雪", "delimiters and UTF-8 survive")
    collectionCheck(okTextListHas(items, 0), "empty value is present")
    collectionCheck(!okTextListHas(items, 3), "out of range absent")
    collectionCheck(!okTextListHas(items, 0 - 1), "negative index absent")
    let record = okRecordNew()
    okRecordPut(record, "name", okTextListAt(items, 1))
    okRecordPut(record, "", "")
    collectionCheck(okRecordHas(record, ""), "empty key and value are present")
    collectionCheck(!okRecordHas(record, "missing"), "missing key absent")
    okRecordPut(record, "name", "replacement")
    collectionCheck(okCollectionCount(record) == 2, "replacement keeps count")
    let saved = okRecordText(record, "name")
    okRecordRemove(record, "name")
    okCollectionRelease(record)
    okCollectionRelease(items)
    drainPool(pool)
    gcCollect()
    collectionCheck(saved == "replacement", "read survives container release and pool drain")
}
