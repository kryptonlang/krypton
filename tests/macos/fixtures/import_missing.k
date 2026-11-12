// Fixture for import-resolution hard-fail: imports a module that does not
// exist anywhere (source-relative, cwd, or install roots).
import "./import_helper_definitely_missing_xyz.k"
just run { print("never reached\n") }
