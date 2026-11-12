// Smoke test: SmackUI geometry + view hierarchy + software surface.
// Pure Krypton, runs on both macOS arm64 and Linux x86_64 backends.

import "k:smack/geometry"
import "k:smack/view"
import "k:smack/compositor"

func check(name, cond) {
    if cond {
        print("[PASS] " + name)
    } else {
        print("[FAIL] " + name)
        exit("1")
    }
    emit 0
}

just run {
    print("SmackUI smoke")

    // ── Geometry ──────────────────────────────────────────────
    let r1 = rect(10, 10, 50, 50)
    check("rect right/bottom", rectRight(r1) == 60 && rectBottom(r1) == 60)
    check("point in rect", rectContainsPoint(r1, point(25, 25)) == 1)
    check("point not in rect", rectContainsPoint(r1, point(100, 100)) == 0)
    let r2 = rect(40, 40, 50, 50)
    check("rect intersects", rectIntersects(r1, r2) == 1)
    let inter = rectIntersection(r1, r2)
    check("intersection size", rectWidth(inter) == 20 && rectHeight(inter) == 20)
    check("rect no intersect", rectIntersects(r1, rect(100, 10, 10, 10)) == 0)
    check("rect contains rect", rectContainsRect(r1, rect(20, 20, 10, 10)) == 1)
    check("rect not contains rect", rectContainsRect(r1, rect(20, 20, 100, 10)) == 0)

    // ── Color math ────────────────────────────────────────────
    let red = colorRGB(255, 0, 0)
    let blue = colorRGB(0, 0, 255)
    check("color red channel", colorRed(red) == 255)
    check("color blue channel", colorBlue(blue) == 255)
    check("color alpha", colorAlpha(red) == 255)
    let mixed = colorAddBlend(red, blue, 128)
    check("blend mid", colorRed(mixed) > 100 && colorBlue(mixed) > 100 && colorGreen(mixed) < 100)
    check("colorTint half", colorRed(colorTint(red, 128, 256)) == 127)
    check("colorTint full", colorRed(colorTint(red, 256, 256)) == 255)
    check("multiply half", colorRed(colorMultiply(red, 128, 256)) == 128)

    // ── View hierarchy ────────────────────────────────────────
    let root = smackView(0, 0, 200, 200, colorRGB(100, 100, 100))
    let c1 = smackView(10, 10, 80, 80, colorRGB(255, 0, 0))
    let c2 = smackView(100, 20, 60, 60, colorRGB(0, 0, 255))
    root = smackAddSubview(root, c1)   // list (front→back): c1
    root = smackAddSubview(root, c2)   // list (front→back): c2, c1
    check("add subviews count", smackSubviewCount(root) == 2)
    check("head is newest (front-most)", smackSameView(smackGetSubviewAt(root, 0), c2) == 1)
    check("tail is oldest", smackSameView(smackGetSubviewAt(root, 1), c1) == 1)
    root = smackRemoveFromSuperview(root, c1)
    check("remove from superview count", smackSubviewCount(root) == 1)
    check("remove from superview head", smackSameView(smackGetSubviewAt(root, 0), c2) == 1)
    root = smackAddSubview(root, c1)   // list: c1, c2
    check("re-add count", smackSubviewCount(root) == 2)

    // ── Hit testing — deepest front-most wins ─────────────────
    let panel = smackView(50, 50, 100, 100, colorRGB(0, 200, 0))
    let btn1 = smackView(70, 70, 40, 40, colorRGB(255, 0, 0))
    let btn2 = smackView(80, 80, 20, 20, colorRGB(255, 255, 0))
    panel = smackAddSubview(panel, btn1)   // panel: btn1
    panel = smackAddSubview(panel, btn2)   // panel: btn2, btn1
    root = smackAddSubview(root, panel)    // root: panel, c1, c2
    // btn1 absolute: (50+70, 50+70)-(160,160); btn2 absolute: (130,130)-(150,150)
    let hit = smackHitTest(root, point(135, 135))
    check("deepest front-most hit", smackSameView(hit, btn2) == 1)
    let hitPanel = smackHitTest(root, point(55, 55))
    check("panel hit", smackSameView(hitPanel, panel) == 1)
    check("miss hit", smackHitTest(root, point(-1, -1)) == "")

    // ── Coordinate conversion ─────────────────────────────────
    // btn1's origin in root space: panel.origin + btn1.origin = (120, 120)
    let rel = smackConvertPoint(point(5, 5), btn1, root)
    check("convert point child→root", pointX(rel) == 125 && pointY(rel) == 125)
    let back = smackConvertPoint(rel, root, btn1)
    check("convert point root→child roundtrip", pointX(back) == 5 && pointY(back) == 5)

    // ── Surface ───────────────────────────────────────────────
    let s = smackSurface(16, 16)
    check("surface created", s != "")
    smackSurfaceClear(s, colorRGB(0, 0, 0))
    smackSurfaceFillRect(s, 2, 2, 10, 10, colorRGB(255, 0, 0))
    let px = smackSurfacePixel(s, 5, 5)
    check("fill pixel", colorRed(px) == 255 && colorAlpha(px) == 255)
    check("fill outer clear", colorRed(smackSurfacePixel(s, 0, 0)) == 0)
    smackSurfaceStrokeRect(s, 2, 2, 10, 10, colorRGB(0, 255, 0), 1)
    check("stroke edge", colorGreen(smackSurfacePixel(s, 2, 2)) == 255)

    // ── Display loop — full tree into a raw buffer ────────────
    let win = smackView(0, 0, 100, 100, colorRGB(64, 64, 64))
    let childA = smackView(10, 10, 30, 30, colorRGB(128, 128, 128))
    let childB = smackView(50, 50, 20, 20, colorRGB(255, 255, 0))
    win = smackAddSubview(win, childA)   // front→back: childA
    win = smackAddSubview(win, childB)   // front→back: childB, childA
    let big = smackSurface(100, 100)
    smackViewDisplayRect(win, big, 0, 0)
    check("display bg", colorRed(smackSurfacePixel(big, 90, 90)) == 64)
    check("display childA", colorRed(smackSurfacePixel(big, 15, 15)) == 128)
    check("display childB", colorRed(smackSurfacePixel(big, 55, 55)) == 255)
    check("display overlap order", colorGreen(smackSurfacePixel(big, 55, 55)) == 255)

    print("[PASS] smackui smoke")
}
