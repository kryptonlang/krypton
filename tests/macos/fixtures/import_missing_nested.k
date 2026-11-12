// Fixture for import-resolution hard-fail: transitive import (this file's
// helper imports a missing module) must also fail, naming the helper.
import "./import_missing_nested_helper.k"
just run { print("never reached\n") }
