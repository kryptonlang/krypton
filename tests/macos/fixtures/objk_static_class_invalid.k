objk object Expected { }
objk object Other { }
objk object Wrong { method make() -> Expected = makeValue }
func makeValue(runtime, self) { emit okKNew(runtime, Other) }
just run { }
