// Fixture for import-resolution hard-fail: an existing but empty import is
// also a compile error (unresolvable content).
import "./import_empty_mod.k"
just run { print("never reached\n") }
