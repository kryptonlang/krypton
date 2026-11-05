# Objective-K On macOS: Live Fields And Tables

This track uses the development checkout on macOS arm64. Installed 2.4.8 does
not contain these additions. No Objective-C/C source, generated source, or Clang
is needed; Objective-K calls Apple's system frameworks through its native ABI.
Use a desktop session. These are not browser/WASM lessons.

## 1. Build A Live Field

From the Krypton checkout root:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 tutorial/macos/01_live_field.ks -o /tmp/objk-live-field
/tmp/objk-live-field
```

Type into the field. The label follows without pressing Return. Use the app
menu's Quit when finished; closing a window is not the same as terminating it.
Read [the complete source](01_live_field.ks).

The handler is an ordinary function. It receives the field, reads its current
text and updates a label. `funcptr` registers the named function; it does not
create a closure or capture local variables:

```krypton
func showText(field) {
    let label = okGet(field, "tutorial.label")
    okSetText(label, okText(field))
    emit 0
}
```

The entry block associates the label with the field, then registers the handler:

```krypton
okSet(field, "tutorial.label", label)
okFieldOnChange(field, funcptr(showText))
```

Native handles stay native. Do not stringify them or store them in K-owned
integer fields. Associations retain object values; this example's label does
not retain the field, so it creates no reference cycle. The field owns its
delegate. Callback return is ignored; `okSetText` does not synthesize another
user edit. Passing 0 to `okFieldOnChange` detaches it. Registration refuses an
existing foreign delegate rather than replacing it.

## 2. Filter A Table

Build the [table/filter example](../../examples/objk/table_filter.ks):

```sh
./bootstrap/kcc_driver_macos_aarch64 examples/objk/table_filter.ks -o /tmp/objk-table-filter
/tmp/objk-table-filter
```

`filterRows` reads the field, builds a filtered native array, clears stale row
selection and reloads the model. Empty query explicitly restores every row.
`okDataSource` retains the data source after the creating function returns;
detach it with `okDataSource(table,0)` when appropriate. The data source must not
strongly retain its own table.

The table now uses `okColumn(table,"c0","Component",440)` to update the default
column and `okColumn(table,"kind","Kind",160)` to add another. The data-source
callback reads the column identifier before choosing cell text. `okColWidth`
and `okRowHeight` use positive integer points. Columns retain their native
objects; this does not introduce language records or string-list columns.

Single/double handlers registered with `okOnClick`/`okOnDoubleClick` receive
only `(table)` and coexist. They are different from generic `okClick` actions
with `(self,command,sender)`. The example saves geometry through `okFrameSave`
on its Quit action and tries `okFrameRestore` at launch; that is not a close hook.

## 3. Read Selection And Preserve Native Keys

`okSelection(table)` returns an immutable NSIndexSet snapshot, not a text list.
`okSelectionCount` counts its rows; `okSelectionAt(snapshot,0)` returns the first
selected row when nonempty. An out-of-range ordinal returns empty text. The
snapshot is autoreleased: retain it explicitly if it must outlive its pool.
Use `okSelectionNew` and `okSelectionAdd` to build a new mutable selection.

The table example registers `tableKey(table,event)`. It returns 1 for Return
and Escape, which it handles. It returns 0 for everything else, letting the
native table keep arrow navigation and type selection. Callback objects are
borrowed; keep handlers short and run UI work on the main thread. Do not block
the callback waiting for a long-running process.

The live-field callback `(field)` and key callback `(table,event)` are different
from K-owned method callbacks `(runtime,self,...)`. See the
[API guide](../../docs/objk_appkit_events_macos.md) for complete contracts and
[grammar notes](../../docs/spec/grammar.md) for the unchanged language syntax.

## 4. Verify

For a separate K-owned model, read [02_owned_model.k](02_owned_model.k).
It uses compiler declarations and prints `42` without opening a window:

```sh
./bootstrap/kcc_driver_macos_aarch64 -r tutorial/macos/02_owned_model.k
```

This is a different layer from native AppKit controls. See the
[Objective-K entry guide](../../docs/objective_k.md) before combining their
ownership systems.

```sh
./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_objk_runtime_macos.ks
```

The focused checker covers the native adapters and K-owned runtime; it is not
the full cross-platform compiler suite. The table demo's real typing, clear,
Down, Return and Escape were verified separately. The live-field tutorial is
compile-checked; no separate interactive tutorial verification is claimed.
Drag/drop, IME, accessibility and other platforms remain separate work.
