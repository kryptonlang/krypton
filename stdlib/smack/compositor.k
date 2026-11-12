// stdlib/smack/compositor.k — software SmackUI surface (pure Krypton).
//
//  SmackSurface: an RGBA pixel buffer allocated via bufNew().
//  Bytes in memory (both backends): RR GG BB AA, then width*height pixels.
//
//    offset = (y * width + x) * 4
//
//  NOTE: bufSetDwordAt is not implemented by the macOS macho backend
//  (calls through to a null function), so this module uses bufGetByte /
//  bufSetByte exclusively — those are implemented on both backends.

module smack_compositor

import "k:smack/geometry"
import "k:smack/view"


// ── Surface ──────────────────────────────────────────────────────

func smackSurface(width, height) {
    if toInt(width) <= 0 { emit "" }
    if toInt(height) <= 0 { emit "" }
    let buf = bufNew(toInt(width) * toInt(height) * 4)
    let s = structNew()
    s = setField(s, "width", toInt(width))
    s = setField(s, "height", toInt(height))
    s = setField(s, "stride", toInt(width) * 4)
    s = setField(s, "buf", buf)
    emit s
}
func smackSurfaceWidth(s)  { if s == "" { emit 0 }  emit getField(s, "width") }
func smackSurfaceHeight(s) { if s == "" { emit 0 }  emit getField(s, "height") }
func smackSurfaceStride(s) { if s == "" { emit 0 }  emit getField(s, "stride") }
func smackSurfaceBuffer(s) { if s == "" { emit "" } emit getField(s, "buf") }

func smackSurfacePixel(s, x, y) {
    if s == "" { emit 0 }
    let w = toInt(getField(s, "width"))
    let h = toInt(getField(s, "height"))
    if toInt(x) < 0 || toInt(x) >= w { emit 0 }
    if toInt(y) < 0 || toInt(y) >= h { emit 0 }
    let off = (toInt(y) * w + toInt(x)) * 4
    let buf = getField(s, "buf")
    let a = bufGetByte(buf, off + 3)
    let b = bufGetByte(buf, off + 2)
    let g = bufGetByte(buf, off + 1)
    let r = bufGetByte(buf, off)
    emit color(r, g, b, a)
}

func smackSurfaceSetPixel(s, x, y, color) {
    if s == "" { emit 0 }
    let w = toInt(getField(s, "width"))
    let h = toInt(getField(s, "height"))
    if toInt(x) < 0 || toInt(x) >= w { emit 0 }
    if toInt(y) < 0 || toInt(y) >= h { emit 0 }
    let off = (toInt(y) * w + toInt(x)) * 4
    let buf = getField(s, "buf")
    let alpha = colorAlpha(color)
    let r = colorRed(color)
    let g = colorGreen(color)
    let b = colorBlue(color)
    if alpha == 255 || alpha == 0 {
        bufSetByte(buf, off, r)
        bufSetByte(buf, off + 1, g)
        bufSetByte(buf, off + 2, b)
        bufSetByte(buf, off + 3, alpha)
        emit 1
    } else {
        // src-over: out = src*a/256 + dst*(256-a)/256, per channel
        let src = alpha + 1
        let inv = 256 - src
        let dr = bufGetByte(buf, off)
        let dg = bufGetByte(buf, off + 1)
        let db = bufGetByte(buf, off + 2)
        let nr = (r * src + dr * inv + 128) / 256
        let ng = (g * src + dg * inv + 128) / 256
        let nb = (b * src + db * inv + 128) / 256
        bufSetByte(buf, off, nr)
        bufSetByte(buf, off + 1, ng)
        bufSetByte(buf, off + 2, nb)
        bufSetByte(buf, off + 3, 255)
        emit 1
    }
}

func smackSurfaceClear(s, color) {
    if s == "" { emit 0 }
    let w = toInt(getField(s, "width"))
    let h = toInt(getField(s, "height"))
    let total = w * h
    let i = 0
    while i < total {
        smackSurfaceSetPixel(s, i % w, i / w, color)
        i += 1
    }
    emit 1
}

func smackSurfaceFillRect(s, rx, ry, rw, rh, color) {
    if s == "" { emit 0 }
    if toInt(rw) <= 0 || toInt(rh) <= 0 { emit 0 }
    let sw = toInt(getField(s, "width"))
    let sh = toInt(getField(s, "height"))
    let x0 = toInt(rx)
    let y0 = toInt(ry)
    if x0 < 0 { x0 = 0 }
    if y0 < 0 { y0 = 0 }
    let x1 = toInt(rx) + toInt(rw)
    let y1 = toInt(ry) + toInt(rh)
    if x1 > sw { x1 = sw }
    if y1 > sh { y1 = sh }
    let y = y0
    while y < y1 {
        let x = x0
        while x < x1 {
            smackSurfaceSetPixel(s, x, y, color)
            x += 1
        }
        y += 1
    }
    emit 1
}

func smackSurfaceStrokeRect(s, rx, ry, rw, rh, color, borderWidth) {
    if s == "" { emit 0 }
    let bw = toInt(borderWidth)
    if bw < 1 { bw = 1 }
    smackSurfaceFillRect(s, rx, ry, rw, bw, color)
    smackSurfaceFillRect(s, rx, toInt(ry) + toInt(rh) - bw, rw, bw, color)
    smackSurfaceFillRect(s, rx, ry, bw, rh, color)
    smackSurfaceFillRect(s, toInt(rx) + toInt(rw) - bw, ry, bw, rh, color)
    emit 1
}


// ── View display ─────────────────────────────────────────────────
//  Draw the view tree onto the surface. (ax, ay) is the surface coordinate
//  of the current coordinate system's origin (0,0). Painter's order:
//  back-to-front — background first, then children oldest-first (subview
//  head is the front-most/newest, so iterate from tail to head).
//  Views are clipped to the surface bounds by smackSurfaceFillRect.
func smackViewDisplayRect(v, s, ax, ay) {
    if v == "" { emit 0 }
    if s == "" { emit 0 }
    let fx = toInt(ax) + toInt(getField(v, "x"))
    let fy = toInt(ay) + toInt(getField(v, "y"))
    let fw = toInt(getField(v, "width"))
    let fh = toInt(getField(v, "height"))
    if fw <= 0 || fh <= 0 { emit 0 }
    smackSurfaceFillRect(s, fx, fy, fw, fh, getField(v, "bg"))
    let n = smackSubviewCount(v)
    let i = n - 1
    while i >= 0 {
        smackViewDisplayRect(smackGetSubviewAt(v, i), s, fx, fy)
        i -= 1
    }
    emit 1
}
