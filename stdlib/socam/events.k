// stdlib/socam/events.k — Button / action target-action bindings for Socam.
//
// Follows the objk ClickHandler idiom: a uniquely-named NSObject subclass
// registers `objk_dispatch:`, attached as the button's target; the associated
// function pointer is invoked with the sender (the NSControl) on click.
module socam_events

import "k:objc"
import "k:choc_macos"

// Bind a button press to a Krypton callback function pointer.
// fn: funcptr() to a function with signature  func cb(self, sender) { ... }
// Reuses chocOnClickKeyed internally under a unique class per button.
func socamOnActivate(control, fnPtr) {
    emit chocOnClick(control, fnPtr)
}

// Bind a button press to a key (unique) so multiple handlers can coexist.
func socamOnActivateKeyed(control, keyName, fnPtr) {
    emit chocOnClickKeyed(control, keyName, fnPtr)
}
