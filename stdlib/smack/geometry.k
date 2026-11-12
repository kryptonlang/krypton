// Copyright 2026 The Krypton Authors.
// Licensed under the Apache License, Version 2.0 (see LICENSE or
// http://www.apache.org/licenses/LICENSE-2.0).
// stdlib/smack/geometry.k — core geometry primitives (pure Krypton).
//
//  SmackPoint / SmackSize / SmackRect are structs with fields:
//    point: { x, y }
//    size:  { width, height }
//    rect:  { x, y, width, height }
//  SmackColor is a "r,g,b,a" comma-string (see the Colors section below).
//
//  Portability notes: min/max are x86_64-Linux-only runtime builtins, not
//  available on the macOS arm64 backend, so this module uses inline _min/_max.
//  Krypton's native int range tops out near 0x7EFFFFFF, so no >2^24 arithmetic
//  is used anywhere in this module.

module smack_geometry


// ── internal numeric helpers ─────────────────────────────────────

func _min(a, b) {
    if toInt(a) < toInt(b) { emit a }
    emit b
}
func _max(a, b) {
    if toInt(a) > toInt(b) { emit a }
    emit b
}


// ── Points ───────────────────────────────────────────────────────

func point(x, y) {
    let p = structNew()
    p = setField(p, "x", toInt(x))
    p = setField(p, "y", toInt(y))
    emit p
}
func pointX(p) { emit getField(p, "x") }
func pointY(p) { emit getField(p, "y") }
func equalPoints(a, b) {
    if getField(a, "x") == getField(b, "x") && getField(a, "y") == getField(b, "y") { emit 1 }
    emit 0
}


// ── Sizes ────────────────────────────────────────────────────────

func size(w, h) {
    let s = structNew()
    s = setField(s, "width", toInt(w))
    s = setField(s, "height", toInt(h))
    emit s
}
func sizeWidth(s) { emit getField(s, "width") }
func sizeHeight(s) { emit getField(s, "height") }
func sizeArea(s) { emit getField(s, "width") * getField(s, "height") }


// ── Rects ────────────────────────────────────────────────────────

func rect(x, y, width, height) {
    let r = structNew()
    r = setField(r, "x", toInt(x))
    r = setField(r, "y", toInt(y))
    r = setField(r, "width", toInt(width))
    r = setField(r, "height", toInt(height))
    emit r
}
func fromOriginSize(origin, s) {
    emit rect(pointX(origin), pointY(origin), sizeWidth(s), sizeHeight(s))
}
func rectOriginX(r) { emit getField(r, "x") }
func rectOriginY(r) { emit getField(r, "y") }
func rectWidth(r)  { emit getField(r, "width") }
func rectHeight(r) { emit getField(r, "height") }
func rectRight(r)  { emit getField(r, "x") + getField(r, "width") }
func rectBottom(r) { emit getField(r, "y") + getField(r, "height") }
func rectContainsPoint(r, p) {
    let px = pointX(p)
    let py = pointY(p)
    if toInt(px) < toInt(rectOriginX(r)) { emit 0 }
    if toInt(py) < toInt(rectOriginY(r)) { emit 0 }
    if toInt(px) >= toInt(rectRight(r))  { emit 0 }
    if toInt(py) >= toInt(rectBottom(r)) { emit 0 }
    emit 1
}
func rectContainsRect(r, inner) {
    if toInt(rectOriginX(inner)) < toInt(rectOriginX(r)) { emit 0 }
    if toInt(rectOriginY(inner)) < toInt(rectOriginY(r)) { emit 0 }
    if toInt(rectRight(inner))  > toInt(rectRight(r))    { emit 0 }
    if toInt(rectBottom(inner)) > toInt(rectBottom(r))   { emit 0 }
    emit 1
}
func rectIntersects(r1, r2) {
    if toInt(rectRight(r1))  <= toInt(rectOriginX(r2)) { emit 0 }
    if toInt(rectRight(r2))  <= toInt(rectOriginX(r1)) { emit 0 }
    if toInt(rectBottom(r1)) <= toInt(rectOriginY(r2)) { emit 0 }
    if toInt(rectBottom(r2)) <= toInt(rectOriginY(r1)) { emit 0 }
    emit 1
}
func rectIntersection(r1, r2) {
    if rectIntersects(r1, r2) == 0 { emit rect(0, 0, 0, 0) }
    let x = _max(rectOriginX(r1), rectOriginX(r2))
    let y = _max(rectOriginY(r1), rectOriginY(r2))
    let r = _min(rectRight(r1),  rectRight(r2))
    let b = _min(rectBottom(r1), rectBottom(r2))
    emit rect(x, y, toInt(r) - toInt(x), toInt(b) - toInt(y))
}
func rectInset(r, dx, dy) {
    emit rect(toInt(rectOriginX(r)) + toInt(dx), toInt(rectOriginY(r)) + toInt(dy),
              toInt(rectWidth(r)) - 2 * toInt(dx), toInt(rectHeight(r)) - 2 * toInt(dy))
}
func rightRect(r, w, h) {
    emit rect(rectRight(r), rectOriginY(r), w, h)
}
func belowRect(r, gap, h) {
    emit rect(rectOriginX(r), toInt(rectBottom(r)) + toInt(gap), rectWidth(r), h)
}
func unionRect(r1, r2) {
    let minX = _min(rectOriginX(r1), rectOriginX(r2))
    let minY = _min(rectOriginY(r1), rectOriginY(r2))
    let maxR = _max(rectRight(r1), rectRight(r2))
    let maxB = _max(rectBottom(r1), rectBottom(r2))
    emit rect(minX, minY, toInt(maxR) - toInt(minX), toInt(maxB) - toInt(minY))
}


// ── Colors — packed "r,g,b,a" comma-strings ─────────────────────
//
//  Krypton's native int range tops out near 0x7EFFFFFF, so a 32-bit packed
//  RGBA integer overflows on the Linux x86_64 backend (252*16777216 crashes
//  the runtime). Colors are therefore carried as "r,g,b,a" strings; channel
//  math stays in small ints. color*() and colorXxx() functions below are the
//  only supported way to build/inspect colors.

func color(r, g, b, a) {
    emit toInt(r) + "," + toInt(g) + "," + toInt(b) + "," + toInt(a)
}
func colorRGB(r, g, b) { emit color(r, g, b, 255) }
func colorRed(c)   { emit toInt(split(c, 0)) }
func colorGreen(c) { emit toInt(split(c, 1)) }
func colorBlue(c)  { emit toInt(split(c, 2)) }
func colorAlpha(c) { emit toInt(split(c, 3)) }
func colorTint(c, numer, denom) {
    // scale toward black by numer/denom (numer <= denom)
    if toInt(numer) > toInt(denom) { numer = denom }
    let num = toInt(numer)
    let den = toInt(denom)
    if den <= 0 { emit c }
    let r = colorRed(c) * num / den
    let g = colorGreen(c) * num / den
    let b = colorBlue(c) * num / den
    emit color(r, g, b, colorAlpha(c))
}
func colorMultiply(c, numer, denom) {
    // scale channels by numer/denom (unity = 256/256)
    let num = toInt(numer)
    let den = toInt(denom)
    if den <= 0 { emit c }
    let r = (colorRed(c)   * num + 128) / den
    let g = (colorGreen(c) * num + 128) / den
    let b = (colorBlue(c)  * num + 128) / den
    emit color(r, g, b, colorAlpha(c))
}
func colorAddBlend(c1, c2, alpha) {
    // c2 over c1 at coverage `alpha` (0..256, 256 = fully c2)
    let a = toInt(alpha)
    if a <= 0   { emit c1 }
    if a >= 256 { emit c2 }
    let r1 = colorRed(c1)
    let g1 = colorGreen(c1)
    let b1 = colorBlue(c1)
    let r2 = colorRed(c2)
    let g2 = colorGreen(c2)
    let b2 = colorBlue(c2)
    let r = (r2 * a + r1 * (256 - a) + 128) / 256
    let g = (g2 * a + g1 * (256 - a) + 128) / 256
    let b = (b2 * a + b1 * (256 - a) + 128) / 256
    emit color(r, g, b, colorAlpha(c1))
}
func colorScreenCombine(c1, c2) {
    // per-channel max (screen blend for opaque channels)
    if colorAlpha(c1) == 0 { emit c2 }
    if colorAlpha(c2) == 0 { emit c1 }
    let r = _max(colorRed(c1), colorRed(c2))
    let g = _max(colorGreen(c1), colorGreen(c2))
    let b = _max(colorBlue(c1), colorBlue(c2))
    emit color(r, g, b, _max(colorAlpha(c1), colorAlpha(c2)))
}
