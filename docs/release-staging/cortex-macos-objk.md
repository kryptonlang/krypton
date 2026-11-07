# macOS 2.4.9 Objective-K File-Manager Support

Prepared while stabilizing Cortex for macOS and shipped in macOS 2.4.9.
Install the matching release to use these APIs; publication does not upgrade
an existing local compiler automatically.

- `okScrollFrame(document,x,y,w,h)` lays out the enclosing NSScrollView.
- `okScrollHidden(document,hidden)` hides/restores that container.
- `okViewWidth(view)` / `okViewHeight(view)` read NSRect bounds through the
  compiler's floating-point/struct return ABI.
- `okSameHandle(a,b)` compares foreign pointer identity numerically, avoiding
  generic equality's string comparison for addresses above 4 GiB.
- `okCopyText(text)` copies borrowed UTF-8 or StringBuilder text into a new
  Krypton allocation. `okObjectText(object)` copies its description (nil is
  empty). Call before the builder mutates or the object's pool drains.

Regression source: `tests/macos/test_objk_scroll_layout.k`.

```sh
kcc tests/macos/test_objk_scroll_layout.k -o /tmp/objk-scroll-layout
/tmp/objk-scroll-layout
```

Validation covers actual content/scroll dimensions, hide/show, non-scroll view
rejection, nil handles and distinct same-class NSTableView instances. All pass
on the local macOS arm64 toolchain.

The Cortex repository also includes the source patch, regression copy and a
separate reproducer of the string-builder interior-pointer collector defect.
That collector issue remains open; use the snapshot helpers for text retained
across collection. A snapshot must remain reachable in a stack local or global;
this does not add transitive tracing for arbitrary buffers. Cortex's existing
Foundation-association workaround remains valid. The raw reproducer still fails;
`tests/macos/test_objk_text_snapshot.k` verifies the explicit safe alternative.
