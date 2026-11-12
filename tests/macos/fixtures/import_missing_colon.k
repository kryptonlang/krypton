// Fixture for import-resolution hard-fail: Odin-style k: prefix imports of
// nonexistent stdlib modules must fail at import resolution time.
import "k:definitely_missing_stdlib_module_xyz_123"
just run { print("never reached\n") }
