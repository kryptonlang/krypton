// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// stdlib/smack/view.k — SmackView base view hierarchy (pure Krypton).
//
//  Views are env-struct values. Krypton structs are immutable values
//  (setField returns a new value), so the tree is built with O(1) prepend
//  linking: each view has `firstSubview` (head) and each head has
//  `nextSibling`. The head is the most recently added child — exactly the
//  front-most (topmost) view for hit-testing.
//
//  Every view carries a small integer `uid` (from a persistent static
//  counter) used for identity; Krypton handle equality across values is not
//  reliable for large env pointers.
//
//  No superview back-pointer is stored (it would break value semantics).
//  Coordinate conversion computes the common-ancestor offset with a bounded
//  DFS instead. Removal is a persistent spine rebuild in _chainRemove.
//
//  Fields: x, y, width, height, bg (packed RGBA int), uid (int),
//          firstSubview (view or ""), nextSibling (view or ""),
//          isUserInteractionEnabled ("1"/"0"), tag (int).

module smack_view

import "k:smack/geometry"

func _vres(head, removed, detached) {
    let r = structNew()
    r = setField(r, "head", head)
    r = setField(r, "removed", toInt(removed))
    r = setField(r, "detached", detached)
    emit r
}
// Structural identity: two views are the same view iff all scalar fields and
// the full child chain match. Handles are excluded because setField creates
// fresh envs on each update; nextSibling is excluded because in-tree nodes
// differ from detached ones only by their successor.
func _sameView(a, b) {
    if a == "" && b == "" { emit 1 }
    if a == "" || b == "" { emit 0 }
    if toInt(getField(a, "x")) != toInt(getField(b, "x")) { emit 0 }
    if toInt(getField(a, "y")) != toInt(getField(b, "y")) { emit 0 }
    if toInt(getField(a, "width")) != toInt(getField(b, "width")) { emit 0 }
    if toInt(getField(a, "height")) != toInt(getField(b, "height")) { emit 0 }
    if getField(a, "bg") != getField(b, "bg") { emit 0 }
    if getField(a, "tag") != getField(b, "tag") { emit 0 }
    if getField(a, "isUserInteractionEnabled") != getField(b, "isUserInteractionEnabled") { emit 0 }
    if _sameChildren(getField(a, "firstSubview"), getField(b, "firstSubview")) == 0 { emit 0 }
    emit 1
}
// Compare two sibling lists pairwise (head-to-head).
func _sameChildren(a, b) {
    if a == "" && b == "" { emit 1 }
    if a == "" || b == "" { emit 0 }
    if _sameView(a, b) == 0 { emit 0 }
    if _sameChildren(getField(a, "nextSibling"), getField(b, "nextSibling")) == 0 { emit 0 }
    emit 1
}
func smackSameView(a, b) { emit _sameView(a, b) }

// ── Construction ─────────────────────────────────────────────────

func smackView(x, y, width, height, bg) {
    let v = structNew()
    v = setField(v, "x", toInt(x))
    v = setField(v, "y", toInt(y))
    v = setField(v, "width", toInt(width))
    v = setField(v, "height", toInt(height))
    v = setField(v, "bg", bg)
    v = setField(v, "firstSubview", "")
    v = setField(v, "nextSibling", "")
    v = setField(v, "isUserInteractionEnabled", "1")
    v = setField(v, "tag", "0")
    emit v
}
func smackViewAtOrigin(x, y, width, height) {
    emit smackView(x, y, width, height, colorRGB(200, 200, 200))
}

// ── Accessors ────────────────────────────────────────────────────

func smackX(v)      { if v == "" { emit 0 }  emit getField(v, "x") }
func smackY(v)      { if v == "" { emit 0 }  emit getField(v, "y") }
func smackWidth(v)  { if v == "" { emit 0 }  emit getField(v, "width") }
func smackHeight(v) { if v == "" { emit 0 }  emit getField(v, "height") }
func smackBg(v)     { if v == "" { emit 0 }  emit getField(v, "bg") }
func smackTag(v)    { if v == "" { emit 0 }  emit getField(v, "tag") }
func smackFrame(v) {
    if v == "" { emit rect(0, 0, 0, 0) }
    emit rect(getField(v, "x"), getField(v, "y"), getField(v, "width"), getField(v, "height"))
}
func smackFrameOriginX(v) { if v == "" { emit 0 }  emit getField(v, "x") }
func smackFrameOriginY(v) { if v == "" { emit 0 }  emit getField(v, "y") }
func smackFrameWidth(v)   { if v == "" { emit 0 }  emit getField(v, "width") }
func smackFrameHeight(v)  { if v == "" { emit 0 }  emit getField(v, "height") }
func smackSetFrame(v, x, y, width, height) {
    if v == "" { emit v }
    v = setField(v, "x", toInt(x))
    v = setField(v, "y", toInt(y))
    v = setField(v, "width", toInt(width))
    v = setField(v, "height", toInt(height))
    emit v
}
func smackSetBg(v, bg) { if v == "" { emit v }  emit setField(v, "bg", bg) }
func smackSetUserInteractionEnabled(v, yes) {
    if v == "" { emit v }
    if toInt(yes) == 0 { emit setField(v, "isUserInteractionEnabled", "0") }
    emit setField(v, "isUserInteractionEnabled", "1")
}
func smackSetTag(v, t) { if v == "" { emit v }  emit setField(v, "tag", toInt(t)) }
func smackUserInteractionEnabled(v) {
    if v == "" { emit 0 }
    if getField(v, "isUserInteractionEnabled") == "1" { emit 1 }
    emit 0
}

// ── Child list helpers ───────────────────────────────────────────
//  List is prepend-linked (head = most recently added = front-most).

func smackSubviewCount(v) {
    if v == "" { emit 0 }
    let n = 0
    let cur = getField(v, "firstSubview")
    while cur != "" {
        n += 1
        cur = getField(cur, "nextSibling")
    }
    emit n
}
// i-th child, counting from the head (0 = front-most). "" when out of range.
func smackGetSubviewAt(v, i) {
    if v == "" { emit "" }
    let cur = getField(v, "firstSubview")
    let k = 0
    while cur != "" {
        if k == toInt(i) { emit cur }
        cur = getField(cur, "nextSibling")
        k += 1
    }
    emit ""
}
// Add child as the new head (front-most). Returns the updated view.
func smackAddSubview(parent, child) {
    if parent == "" || child == "" { emit parent }
    let newChild = setField(child, "nextSibling", getField(parent, "firstSubview"))
    emit setField(parent, "firstSubview", newChild)
}

// Recursively splice `target` out of the sibling list headed at `head`.
func _chainRemove(head, target) {
    if head == "" { emit _vres("", 0, "") }
    if _sameView(head, target) == 1 {
        let detached = setField(head, "nextSibling", "")
        emit _vres(getField(head, "nextSibling"), 1, detached)
    }
    let sub = _detachInView(head, target)
    let newHead = head
    if getField(sub, "removed") == 1 {
        newHead = getField(sub, "node")
    }
    let tail = _chainRemove(getField(head, "nextSibling"), target)
    if getField(tail, "removed") == 1 {
        newHead = setField(newHead, "nextSibling", getField(tail, "head"))
        emit _vres(newHead, 1, getField(tail, "detached"))
    }
    if getField(sub, "removed") == 1 {
        emit _vres(newHead, 1, getField(sub, "detached"))
    }
    emit _vres(newHead, 0, "")
}

// Splice `target` out of `node`'s subtree. Result: { node, removed, detached }.
func _detachInView(node, target) {
    if node == "" {
        let r = structNew()
        r = setField(r, "node", node)
        r = setField(r, "removed", 0)
        r = setField(r, "detached", "")
        emit r
    }
    if _sameView(node, target) == 1 {
        let r = structNew()
        r = setField(r, "node", "")
        r = setField(r, "removed", 1)
        r = setField(r, "detached", setField(node, "nextSibling", ""))
        emit r
    }
    let sub = _chainRemove(getField(node, "firstSubview"), target)
    if getField(sub, "removed") == 1 {
        let r = structNew()
        r = setField(r, "node", setField(node, "firstSubview", getField(sub, "head")))
        r = setField(r, "removed", 1)
        r = setField(r, "detached", getField(sub, "detached"))
        emit r
    }
    let r = structNew()
    r = setField(r, "node", node)
    r = setField(r, "removed", 0)
    r = setField(r, "detached", "")
    emit r
}

// Remove `target` from anywhere in root's tree. Returns the updated root.
func smackRemoveFromSuperview(root, target) {
    if root == "" || target == "" { emit root }
    let sub = _detachInView(root, target)
    emit getField(sub, "node")
}

// ── Coordinate conversion ────────────────────────────────────────
//  DFS that finds `target` under `node`, accumulating the target's origin in
//  `node`'s coordinate space. Result struct: { found, x, y }.
func _findAccum(node, target, dx, dy) {
    let r = structNew()
    if node == "" {
        r = setField(r, "found", 0)
        r = setField(r, "x", 0)
        r = setField(r, "y", 0)
        emit r
    }
    if _sameView(node, target) == 1 {
        r = setField(r, "found", 1)
        r = setField(r, "x", toInt(dx))
        r = setField(r, "y", toInt(dy))
        emit r
    }
    let cur = getField(node, "firstSubview")
    while cur != "" {
        let cx = toInt(dx) + toInt(getField(cur, "x"))
        let cy = toInt(dy) + toInt(getField(cur, "y"))
        let sub = _findAccum(cur, target, cx, cy)
        if getField(sub, "found") == 1 { emit sub }
        cur = getField(cur, "nextSibling")
    }
    r = setField(r, "found", 0)
    r = setField(r, "x", 0)
    r = setField(r, "y", 0)
    emit r
}

// Convert `point` from fromView's coordinate system into toView's,
// computing relative placement by tree search. Both views must live in a
// shared hierarchy; if the two trees are unrelated, the offset defaults to 0.
func smackConvertPoint(point, fromView, toView) {
    if fromView == "" || toView == "" { emit point }
    if _sameView(fromView, toView) == 1 { emit point }
    // case 1: fromView lives under toView
    let a = _findAccum(toView, fromView, 0, 0)
    if getField(a, "found") == 1 {
        emit point(toInt(pointX(point)) + toInt(getField(a, "x")),
                   toInt(pointY(point)) + toInt(getField(a, "y")))
    }
    // case 2: toView lives under fromView
    let b = _findAccum(fromView, toView, 0, 0)
    if getField(b, "found") == 1 {
        emit point(toInt(pointX(point)) - toInt(getField(b, "x")),
                   toInt(pointY(point)) - toInt(getField(b, "y")))
    }
    emit point
}

// ── Hit testing ──────────────────────────────────────────────────
//  Return the deepest front-most (most recently added) enabled view whose
//  frame contains `point` (in v's coordinate system; v's own frame is
//  expressed in v's parent's space, i.e. pass the point in v's parent space).
//  "" when nothing hits.
func smackHitTest(v, point) {
    if v == "" { emit "" }
    if smackUserInteractionEnabled(v) == 0 { emit "" }
    let r = smackFrame(v)
    if rectContainsPoint(r, point) == 0 { emit "" }
    let childPoint = point(toInt(pointX(point)) - toInt(getField(v, "x")),
                           toInt(pointY(point)) - toInt(getField(v, "y")))
    // head = front-most → hit it first (reverse subview order)
    let cur = getField(v, "firstSubview")
    while cur != "" {
        let hit = smackHitTest(cur, childPoint)
        if hit != "" { emit hit }
        cur = getField(cur, "nextSibling")
    }
    emit v
}

// ── Tag lookup ───────────────────────────────────────────────────
func smackFindByTag(v, tag) {
    if v == "" { emit "" }
    if getField(v, "tag") == toInt(tag) { emit v }
    let cur = getField(v, "firstSubview")
    while cur != "" {
        let hit = smackFindByTag(cur, tag)
        if hit != "" { emit hit }
        cur = getField(cur, "nextSibling")
    }
    emit ""
}
