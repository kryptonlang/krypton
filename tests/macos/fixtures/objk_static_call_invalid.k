objk object Wrong {
    method answer(value: int) -> int = answerValue
    method other() -> int = otherValue
}
func answerValue(runtime, self, value) { emit value }
func otherValue(runtime, self) { emit answerValue(runtime, self, "wrong") }
just run { }
