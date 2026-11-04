objk object Counter {
    method value() -> int = counterValue
}

func counterValue(runtime, self) {
    emit okKGet(runtime, self, "value")
}

just run {
    let counter = okKNew(__objkRuntime, Counter)
    doKSet(__objkRuntime, counter, "value", 42)
    print(okKSend(__objkRuntime, counter, "value"))
    doKRelease(__objkRuntime, counter)
}
