# Unreleased: macOS Objective-K file-manager support

Prepared while stabilizing Cortex for macOS. SDK changes only; the installed
compiler executable and package version have not been changed.

- `okScrollFrame(document,x,y,w,h)` lays out the enclosing NSScrollView.
- `okScrollHidden(document,hidden)` hides/restores that container.
- `okViewWidth(view)` / `okViewHeight(view)` read NSRect bounds through the
  compiler's floating-point/struct return ABI.
- `okSameHandle(a,b)` compares foreign pointer identity numerically, avoiding
  generic equality's string comparison for addresses above 4 GiB.

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
That collector issue remains open; Cortex retains persistent text through
Foundation associations and copies foreign UTF-8 strings before use.
