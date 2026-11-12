// examples/smack_hello.k — smallest end-to-end SmackUI check.
// Compiles and runs inside KryptOS with the ISO-shipped Linux x86_64 kcc:
//   kcc examples/smack_hello.k -o /tmp/smack_hello && /tmp/smack_hello
// Prints "smack-iso-ok" on success.
import "k:smack/geometry"
import "k:smack/view"
import "k:smack/compositor"

just run {
    let root = smackView(0, 0, 32, 32, colorRGB(64, 64, 64))
    let child = smackView(4, 4, 24, 24, colorRGB(255, 0, 0))
    root = smackAddSubview(root, child)
    let s = smackSurface(32, 32)
    smackViewDisplayRect(root, s, 0, 0)
    let px = smackSurfacePixel(s, 8, 8)
    if colorRed(px) == 255 && colorAlpha(px) == 255 && smackSubviewCount(root) == 1 {
        print("smack-iso-ok")
    } else {
        print("smack-iso-fail")
        exit("1")
    }
}
