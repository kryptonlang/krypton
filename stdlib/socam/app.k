// stdlib/socam/app.k — Application lifecycle for Socam (macOS, pure Krypton).
//
// Wraps NSApplication / NSApp behind a lightweight struct handler
// (`socam_app`) so app entrypoints don't write raw msg() chains.
module socam_app

import "k:objc"
import "k:choc_macos"

// Create the shared application instance and set the activation policy.
// policy: 0 = regular (has menubar/dock), 1 = accessory (no UI), 2 = prohibited.
func socamAppShared() {
    let app = structNew()
    let ptr = chocSharedApp()
    app = setField(app, "ptr", ptr)
    emit app
}
func socamAppSetPolicy(app, policy) {
    let ptr = getField(app, "ptr")
    msg_1(ptr, "setActivationPolicy:", policy)
    emit app
}
func socamAppFinishLaunching(app) {
    let ptr = getField(app, "ptr")
    chocFinishLaunching(ptr)
    emit app
}
func socamAppRun(app)       { emit chocRun(getField(app, "ptr")) }
func socamAppQuit(app)      { emit chocQuit(getField(app, "ptr")) }
func socamAppPumpEvents(app){ emit chocPumpEvents(getField(app, "ptr")) }
