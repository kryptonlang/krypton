objk object Wrong {
    method answer() -> int = sharedValue
    method label() -> text = sharedValue
}
func sharedValue(runtime, self) { emit okKGet(runtime, self, "value") }
just run { }
