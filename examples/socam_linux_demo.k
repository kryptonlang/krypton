// examples/socam_linux_demo.k — Socam/Linux smoke: connect, create window, attach, present.
// Runs headless gracefully: without a Wayland server, wlConnect returns -1
// and we exit with code 1 + "connect failed".
//
//   kcc_driver_linux_x86_64 examples/socam_linux_demo.k -o /tmp/socam_demo
//   /tmp/socam_demo
import "k:socam_linux/app"
import "k:socam_linux/window"
import "k:smack/compositor"
import "k:smack/geometry"

just run {
    let app = socamLinuxAppConnect()
    if app == 0 {
        print("connect failed")
        exit("1")
    }

    let win = socamLinuxWindowCreate(app, 320, 240, "Socam-Linux Smoke")
    if win == 0 {
        print("window create failed")
        exit("1")
    }

    let surf = smackSurface(320, 240)
    smackSurfaceClear(surf, colorRGB(16, 16, 48))
    smackSurfaceFillRect(surf, 40, 40, 220, 160, colorRGB(31, 164, 99))
    smackSurfaceFillRect(surf, 80, 80, 140, 80, colorRGB(255, 128, 0))

    let ackd = socamLinuxAppDrain(app, win)
    if ackd == 0 {
        print("no configure from compositor")
        exit("1")
    }
    win = socamLinuxAppRepaint(app, win, surf)
    if win == 0 {
        print("repaint failed")
        exit("1")
    }
    print("socam_linux_demo: ok")
    exit("0")
}
