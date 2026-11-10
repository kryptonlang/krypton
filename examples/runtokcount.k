just run {
  let src = readFile("compiler/run.k")
  let toks = tokenize(src)
  print("Run.k token count: " + lineCount(toks))
  emit "ok"
}
