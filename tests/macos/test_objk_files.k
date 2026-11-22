import "k:objc"
import "k:objk_collections_macos"
import "k:objk_files_macos"
func fileCheck(value, message) {
    if value == 0 { print("FAIL " + message); exit(1) }
    print("PASS " + message)
}
just run {
    let pool = newPool()
    let root = arg(0)
    let names = okDirectoryNames(root)
    fileCheck(names != 0, "directory query succeeds")
    fileCheck(okCollectionCount(names) == 3, "all names returned")
    let record = okFileRecord(root + "/comma,tab\tline\n雪")
    fileCheck(record != 0, "delimiter filename metadata")
    fileCheck(okRecordText(record, "name") == "comma,tab\tline\n雪", "filename lossless")
    fileCheck(okRecordText(record, "size") == "5", "exact size text")
    fileCheck(okRecordText(record, "type") == "NSFileTypeRegular", "regular type")
    okCollectionRelease(record)
    record = okFileRecord(root + "/link")
    fileCheck(okRecordText(record, "type") == "NSFileTypeSymbolicLink", "symlink is not followed")
    fileCheck(okRecordText(record, "symlinkTarget") == "comma,tab\tline\n雪", "symlink target lossless")
    okCollectionRelease(record)
    fileCheck(okFileRecord(root + "/missing") == 0, "missing metadata fails explicitly")
    fileCheck(okDirectoryNames(root + "/missing") == 0, "missing directory fails explicitly")
    okCollectionRelease(names)
    drainPool(pool)
}
