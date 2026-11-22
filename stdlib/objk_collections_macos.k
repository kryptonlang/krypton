// Lossless Foundation collections for Objective-K. macOS only.
// New containers are owned (+1); release with okCollectionRelease. Stored text
// is copied into NSString. Reads return independent Krypton text snapshots.
// Handles are native objects: never compare them using generic text equality.
module objk_collections_macos
import "k:objc"
func okTextListNew() { emit allocInit("NSMutableArray") }
func okRecordNew() { emit allocInit("NSMutableDictionary") }
func okCollectionRelease(container) { msg(container, "release"); emit 0 }
func okCollectionCount(container) { emit msg(container, "count") }
func okTextListAdd(container, text) {
    msg_1(container, "addObject:", nsString(text))
    emit msg(container, "count")
}
// Invalid indexes return empty text; use the boolean predicate to distinguish
// an absent value from a stored empty string.
func okTextListHas(container, index) {
    emit index >= 0 && index < msg(container, "count")
}
func okTextListAt(container, index) {
    if !okTextListHas(container, index) { emit "" }
    let text = nsToStr(msg_1(container, "objectAtIndex:", index))
    emit substring(text, 0, len(text))
}
func okRecordPut(record, key, text) {
    msg_2(record, "setObject:forKey:", nsString(text), nsString(key))
    emit 1
}
func okRecordHas(record, key) {
    emit msg_1(record, "objectForKey:", nsString(key)) != 0
}
func okRecordText(record, key) {
    let text = nsToStr(msg_1(record, "objectForKey:", nsString(key)))
    emit substring(text, 0, len(text))
}
func okRecordRemove(record, key) {
    msg_1(record, "removeObjectForKey:", nsString(key))
    emit 1
}
