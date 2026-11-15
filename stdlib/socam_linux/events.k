// stdlib/socam_linux/events.k — events for Socam/Linux.
//
// Wayland events arrive as (objectId, opcode, args...) triplets over the
// wire. This module records the app's interest in specific (object, opcode)
// pairs and dispatches those events to a Krypton callback.
//
// A callback is a funcptr() to a function with signature:
//   func(ctx, obj, op, off, sizeB) -> void
// ctx is whatever the app stashed at registration time (typically the app
// handle or a window handle); obj, op, off, sizeB identify the raw event
// (windowId, opcode, byte offset into the event buffer, event length).
module socam_linux_events

import "k:wayland"

// Register a callback for a single (objectId, opcode) pair on the app.
// Returns 1 on success, 0 on failure (e.g. already registered).
func socamLinuxOnEvent(app, objectId, opcode, ctx, handlerFn) {
    let key = toStr(objectId) + ":" + toStr(opcode)
    let existing = getField(app, "handler_" + key)
    if existing != 0 { emit 0 }
    app = setField(app, "handler_" + key, handlerFn)
    app = setField(app, "handler_ctx_" + key, ctx)
    emit app
}

// Return the handler registered for (objectId, opcode), or 0 if none.
func socamLinuxEventHandler(app, objectId, opcode) {
    let key = toStr(objectId) + ":" + toStr(opcode)
    emit getField(app, "handler_" + key)
}

// Return the context registered for (objectId, opcode), or 0 if none.
func socamLinuxEventContext(app, objectId, opcode) {
    let key = toStr(objectId) + ":" + toStr(opcode)
    emit getField(app, "handler_ctx_" + key)
}
