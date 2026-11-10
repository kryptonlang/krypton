just run {
  let src = readFile("examples/hello.k")
  let toks = tokenize(src)
  print("TOKEN COUNT: " + lineCount(toks))
  let i = 0
  while i < lineCount(toks) {
    print("[" + i + "] " + tokAt(toks, i))
    i += 1
  }
  emit "ok"
}
