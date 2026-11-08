# Objective-K AppKit Events And Lifecycle

macOS arm64 APIs shipped in 2.4.9. Import `k:okui` or `k:objk`.
Implementation stays in `stdlib/choc_macos.k`; the framework-free object core
and Windows adapters are unchanged. These APIs are not a Windows/Linux parity
claim. Older compilers must be updated alongside their stdlib.

## Table Model And Selection

### Text Snapshots And Scroll Layout

`okCopyText(text)` copies NUL-terminated borrowed text into a separate Krypton
allocation. `okObjectText(object)` snapshots its native description; nil returns
empty text. Copy before a builder mutates or a native autorelease pool drains.
Keep the result rooted in a stack local/global while using `gcCollect`. Raw
`sbToString` interior pointers are not safe collector roots; this explicit copy
does not introduce transitive tracing of arbitrary containers.

`okScrollFrame(document,x,y,w,h)` and `okScrollHidden(document,hidden)` operate
on the enclosing NSScrollView, returning "0" when none exists. Read native
dimensions with `okViewWidth(view)`/`okViewHeight(view)` (NSRect return ABI).
Compare native identities with `okSameHandle(a,b)`, not generic `==`.

At the low-level bridge use `msgRectHeight(view,"frame")` and
`msgRectWidth(view,"frame")`. Do not use `msgRectHeight(msg(view,"frame"))`:
`frame` returns four floating-point components, not an object handle, and the
outer helper would also be missing its selector-name argument. The development
macOS backend rejects wrong argument counts for defined Krypton functions,
including imported helpers; released 2.4.9 does not contain this new diagnostic.
It still cannot infer a native method signature from an arbitrary string.

Non-literal NUL-terminated UTF-8 names are supported by `sel(name)` and the
`msg*` selector-name parameters. `sel` returns a native selector handle, whereas
`msg*` takes the name, not that handle. Selector registration is synchronous;
keep the input alive and unmodified through the call. Native object arguments
are separate: `nsString(text)` makes an autoreleased NSString; retain objects
needed beyond their pool, or use an API with a documented retaining/copying
contract. `cocoaSetAssocKey(owner,key,value)` retains a native object value;
raw Krypton text/buffers/arena handles are not native objects. Wrap text with
`nsString`, and clear the association with 0 when finished. Copy borrowed UTF-8
with `okCopyText`/`okObjectText` before the owning native object is released.

The GUI selector/pool regression exercises composed selector names, mutated key
builders, collection, retained associations and 100 per-frame pools with event
pumping. It does not establish arbitrary foreign signatures or thread safety.

### Selection Contracts

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

## Columns And Mouse Actions

`okColumn(table,id,title,width)` adds a named column or updates an existing one;
it returns the native column borrowed from the table, or 0 for invalid input.
The existing default column has identifier `"c0"`; reuse it instead of adding a
second unwanted default. Data-source callbacks inspect the column's identifier
to return each cell. `okColWidth(table,id,width)` and `okRowHeight(table,height)`
return `"0"` for unknown/nil targets or nonpositive sizes. Sizes currently use
integer points through the native CGFloat adapter. AppKit may clamp column
width to that column's configured minimum/maximum.

`okOnClick(table,funcptr(handler))` and `okOnDoubleClick(table,funcptr(handler))`
take handlers with **one argument `(table)`**, unlike generic `okClick` action
handlers `(self,command,sender)`. Both can coexist, be rebound independently,
and be detached with pointer 0. Read selection through the selection APIs.
These hooks require an `okTable` instance and refuse to overwrite another
action target. Do not mix them with generic `okClick`/`okOn` on the same table.
They do not install or replace a table delegate or implement column sorting.

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

## Images, Menus, And Window Frames

- `okImageView(win,x,y,w,h)` creates an aspect-preserving native image view.
  `okImageFromFile(view,path)` returns `"1"` on load or `"0"` on failure; failure
  leaves the current image unchanged. The view retains a successfully loaded
  image. No image-format support beyond the system NSImage decoder is promised.
- `okMenuCheck(menu,title,on)` finds an item by title and sets checked state.
  `okMenuEnabled(menu,title,on)` sets enabled state and **disables automatic
  item validation for that entire menu** so AppKit does not overwrite the
  requested state. Use only when the app takes responsibility for that menu's
  item states; missing items return `"0"` without changing validation policy.
- `okFrameSave(win,key)` saves current geometry in this application's defaults.
  `okFrameRestore(win,key)` reads it and returns the native success result.
  Empty keys/nil windows or unavailable displays return `"0"`. Save explicitly
  at an appropriate app lifecycle event; these calls install no close/reopen
  delegate, add no single-instance policy, and do not create an app bundle.

The extra native regression checks column geometry, independent action routing,
menu validation, image-load failure preservation and frame restoration. Frame
checks explicitly skip when no display is available; they were also run against
the desktop display and passed without skipping. It creates/removes only its
own uniquely named frame preference. Actual single/double-click actions were
also verified in the native demo. Image preview interaction is not claimed from
the target/action regression.

## Window And Application Lifecycle

These macOS helpers install a retained Krypton-defined native delegate, not a
K-owned object or generated Objective-C source. They return `"1"` for an accepted
registration/detachment and `"0"` for nil targets, allocation failure, or an
existing foreign delegate. They never forward to or replace a foreign delegate.

| Registration | Handler | Contract |
| --- | --- | --- |
| `okWindowShouldClose(win,funcptr(handler))` | `(win)` | Return integer 1 to permit a user close, 0 to veto. |
| `okWindowOnClose(win,funcptr(handler))` | `(win)` | Called from `windowWillClose:`; result ignored; too late to veto. |
| `okAppOnOpenFile(app,funcptr(handler))` | `(app,path)` | `path` is borrowed UTF-8 text; return integer 1 if handled, 0 if rejected. |
| `okAppOnReopen(app,funcptr(handler))` | `(app,hasVisibleWindows)` | Native Boolean visibility; return integer 1 to permit AppKit's default reopen behavior, 0 if fully handled. |

Pointer 0 removes only that hook. The paired window hooks share one delegate;
the two application hooks share another. Removing the last hook clears the
delegate and releases the adapter's reference. Rebinding changes only one
handler; windows remain independent. A callback may detach itself safely. Do not
release its window/application from inside the callback. Do not overwrite the
delegate manually while hooks are active. All registration and dispatch require
the main thread; code pointers and native borrowed arguments are not type- or
lifetime-checked by the compiler.

`performClose:` (including the normal close button) consults `windowShouldClose:`;
direct `close` bypasses that veto. A missing veto handler permits closing. A
missing open-file handler rejects the file; a missing reopen handler permits
default native behavior while another application hook is installed. Only
integer result 1 is accepted as true; arbitrary text is not a Boolean contract.
Quit does not necessarily deliver `windowWillClose:`: save separately in the
Quit action when needed. These helpers do not implement termination callbacks.

The adapter never retains the owner through its delegate. Applications reopening
a closed window must keep a valid strong reference and set
`msg_1(win,"setReleasedWhenClosed:",0)` before closing. `okShow` reuses a live
window; it does not recreate a deallocated window or implement second-process
coordination. Do not create an owner/delegate retention cycle with associations.

Register application hooks before `okRun`/`okFinish`, so launch events can be
delivered. Open-file dispatch uses AppKit's `application:openFile:` contract;
Finder associations additionally require bundle document declarations such as
`CFBundleDocumentTypes`. No bundle metadata, URL/multi-file delegate, sandbox
permission, security-scoped resource access, or NSDocument integration is added.
Do not infer actual Finder routing from a direct delegate regression.

`tests/macos/test_objk_lifecycle.k` checks native `performClose:` veto and close
notifications, per-window isolation, rebinding, independent detachment, foreign
delegate refusal, self-detachment, and direct application open-file/reopen
dispatch. Window checks explicitly skip when no display is available.

## Example And Verification

From the Krypton checkout:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 examples/objk/table_filter.ks -o /tmp/objk-table-filter
/tmp/objk-table-filter
```

The example filters six component names in two columns as text is edited. Empty
query restores all rows. Single/double actions update status independently.
Unhandled arrow keys navigate normally; Return displays the selected
item and Escape clears selection. It preserves native theme and edit-menu
commands. It saves the window frame on close and Quit, attempts restore at launch,
and reopens its retained window through the application reopen hook.
The data source and filtering logic are Krypton, with no C/Objective-C
source or external compiler.

`tests/macos/test_objk_table_events.k` covers selection snapshots/bounds,
retained data sources, independent/rebound key handlers, live notifications,
delegate detachment and refusal to replace another delegate. The runtime checker
includes it. Actual demo typing, filter clearing, Down, Return and Escape were
also verified through the native UI, as were two-column single/double-click
actions and closing/reopening with the filter state retained. Drag/drop, IME
composition, VoiceOver, actual Finder file routing and other platforms are not
claimed as verified here.
