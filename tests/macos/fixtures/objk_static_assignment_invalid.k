objk object Wrong { method answer(value: int) -> int = answerValue }
func answerValue(runtime, self, value) { value = "wrong"; emit value }
just run { }
