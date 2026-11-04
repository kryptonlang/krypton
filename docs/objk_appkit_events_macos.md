# Objective-K AppKit Table And Field Events

Development source APIs for macOS arm64. Import `k:okui` or `k:objk`.
Implementation stays in `stdlib/choc_macos.k`; the framework-free object core
and Windows adapters are unchanged. These APIs are not a Windows/Linux parity
claim and are not yet part of a published compiler release.

## Table Model And Selection

`okTable(win,x,y,w,h)` returns a document table inside a scroll view, as before.
It now uses a Krypton-defined NSTableView subclass with native keyboard fallback.
Existing table data sources/delegates remain supported; the keyboard hook does
not replace either delegate. Existing callback encodings remain unchanged.

| API | Contract |
| --- | --- |
| `okDataSource(table,source)` | Set and retain the native data source; 0 detaches it. |
| `okReload(table)` | Reload the current model. |
| `okMultiSelect(table,enabled)` | Enable/disable native multiple selection. |
| `okSelectionNew()` | Autoreleased mutable NSMutableIndexSet builder. |
| `okSelectionAdd(rows,row)` | Add a nonnegative row; return `"0"` for nil/immutable sets. |
| `okSelection(table)` | Autoreleased immutable snapshot of selected row indexes. |
| `okSelectionCount(rows)` | Number of selected indexes, not table row count. |
| `okSelectionAt(rows,offset)` | Row at zero-based ordinal; empty text if out of range. |
| `okSelect(table,rows)` | Replace selection with an NSIndexSet. |
| `okSelectExtend(table,rows,extend)` | Replace or extend selection. |
| `okSelectRow(table,row,extend)` | Select one valid row. |
| `okSelectNone(table)` / `okSelectAll(table)` | Clear/select all using AppKit behavior. |
| `okScrollTo(table,row)` | Scroll a valid row into view. |

Selection inputs are native index-set handles, not comma/TAB-separated text.
Snapshots do not change when table selection changes. Keep an autorelease pool;
retain a snapshot explicitly if it must survive the pool. Selection/scroll
mutations return `"1"` on an accepted request and `"0"` for invalid rows or nil
targets. Invalid rows leave selection unchanged. AppKit still enforces delegate
vetoes and single/multiple/empty-selection policy; accepted does not override a
delegate. Check the resulting snapshot when the actual selection matters.

Changing the model may invalidate row indexes. Applications should clear or
remap selection when filtering, then reload. Data sources must implement the
native table callback signatures. Detach them with `okDataSource(table,0)` to
release the adapter's reference. Avoid a data source strongly retaining its
table, which would create an ownership cycle.

## Keyboard Hook

`okOnKeyDown(table,funcptr(handler))` accepts a table created by `okTable`.
The callback receives `(table,event)` and returns integer 1 to consume the event
or 0 to preserve NSTableView's `keyDown:` behavior. Arrow navigation and type
selection remain native when not consumed. Return promptly; do not run blocking
processes here. Rebinding affects only that table. Passing 0 detaches the hook.
Foreign NSTableView instances return `"0"` rather than silently claiming a hook.

`okKeyCode(event)`, `okKeyModifiers(event)` and `okKeyText(event)` expose the
borrowed NSEvent's key code, modifier mask, and UTF-8 characters. These are macOS
event values, not portable key constants. Do not keep an event beyond callback
scope without retaining it. Command-key menu actions still use AppKit's normal
menu/responder processing; the hook does not promise to intercept all shortcuts.

## Live Text Changes

`okFieldOnChange(field,funcptr(handler))` installs an owned native text delegate.
The callback receives `(field)` after a native text-change notification. Read
the current text with `okText(field)`; return value is ignored. This does not
replace the field's target/action, so Return actions can remain separate.

Rebinding reuses the owned delegate and changes only the handler. Passing 0
detaches it. If another delegate is installed, registration returns `"0"` with
a diagnostic and leaves it untouched. The field retains its delegate and boxed
callback pointer; no module-global state is required. `okSetText` alone does
not synthesize a user-edit notification or call the handler.

All APIs and callbacks in this guide require the AppKit main thread. Callbacks
and object handles remain native ABI values; these helpers cannot make invalid
pointers or incorrectly declared functions safe.

## Example And Verification

From the Krypton checkout:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 examples/objk/table_filter.ks -o /tmp/objk-table-filter
/tmp/objk-table-filter
```

The example filters six component names as text is edited. Empty query restores
all rows. Unhandled arrow keys navigate normally; Return displays the selected
item and Escape clears selection. It preserves native theme and edit-menu
commands. The data source and filtering logic are Krypton, with no C/Objective-C
source or external compiler.

`tests/macos/test_objk_table_events.k` covers selection snapshots/bounds,
retained data sources, independent/rebound key handlers, live notifications,
delegate detachment and refusal to replace another delegate. The runtime checker
includes it. Actual demo typing, filter clearing, Down, Return and Escape were
also verified through the native UI. Drag/drop, IME composition, VoiceOver,
multi-column tables and other platforms are not claimed as verified here.
