// Foundation filesystem queries without delimiter-packed filenames.
// macOS only. Returned objects are owned; release using okCollectionRelease.
// File attributes are textual record fields, preserving full decimal sizes.
// This module never follows directory symlinks recursively or modifies files.
module objk_files_macos
import "k:objc"
import "k:objk_collections_macos"
func okDirectoryNames(path) {
    let names = msg_2(msg(cls("NSFileManager"), "defaultManager"), "contentsOfDirectoryAtPath:error:", nsString(path), 0)
    if names == 0 { emit 0 }
    emit msg(names, "mutableCopy")
}
func okFileRecord(path) {
    let manager = msg(cls("NSFileManager"), "defaultManager")
    let attrs = msg_2(manager, "attributesOfItemAtPath:error:", nsString(path), 0)
    if attrs == 0 { emit 0 }
    let result = okRecordNew()
    okRecordPut(result, "path", path)
    okRecordPut(result, "name", nsToStr(msg(nsString(path), "lastPathComponent")))
    okRecordPut(result, "type", nsToStr(msg_1(attrs, "objectForKey:", nsString("NSFileType"))))
    okRecordPut(result, "size", nsToStr(msg_1(attrs, "objectForKey:", nsString("NSFileSize"))))
    okRecordPut(result, "modified", nsToStr(msg_1(attrs, "objectForKey:", nsString("NSFileModificationDate"))))
    okRecordPut(result, "permissions", nsToStr(msg_1(attrs, "objectForKey:", nsString("NSFilePosixPermissions"))))
    if okRecordText(result, "type") == "NSFileTypeSymbolicLink" {
        okRecordPut(result, "symlinkTarget", nsToStr(msg_2(manager, "destinationOfSymbolicLinkAtPath:error:", nsString(path), 0)))
    }
    emit result
}
