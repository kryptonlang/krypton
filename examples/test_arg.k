just run {
  let src = "hello\r\nworld"
  let i = 0
  let srcLen = len(src)
  print("len=" + srcLen)
  while i < srcLen {
    let ch = src[i]
    i += 1
  }
  print("done, i=" + i)
  emit "ok"
}