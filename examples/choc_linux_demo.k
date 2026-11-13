// examples/choc_linux_demo.k — Linux Choc slice demo (pure Krypton + Wayland + SmackUI).
//
//   KRYPTON_ROOT=<krypton> kcc_driver_linux_x86_64 examples/choc_linux_demo.k -o /tmp/choc_demo
//   /tmp/choc_demo
//
// Opens a 480x320 Wayland window titled "choc-linux", paints a dark background
// with a green panel and "pure Krypton" text via the SmackSurface path, and
// exits. Exists as a build/link-time regression check for k:choc_linux, not as
// an interactive app. Without a Wayland compositor (headless/CI) it prints
// "connect failed" and exits 1, which is the expected smoke-test outcome.
import "k:choc_linux"

just run {
    let app = chocSharedApp()
    let win = chocWindow(app, "choc-linux", 480, 320)
    chocShow(win, app)
    chocClear(win, colorRGB(30, 30, 32))                    // #1e1e20
    chocFillRect(win, 40, 60, 220, 90, colorRGB(31, 164, 99)) // #1FA463 green panel
    chocStrokeRect(win, 40, 60, 220, 90, colorRGB(56, 206, 132), 2)
    chocDrawText(win, 58, 100, "pure Krypton", colorRGB(232, 232, 235))
    chocDrawText(win, 40, 30, "k:choc_linux - Wayland + SmackUI", colorRGB(136, 144, 153))
    chocPresent(win)
    print("choc-linux-demo ready")
}
