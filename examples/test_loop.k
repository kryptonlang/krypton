just run {
  let src = readFile(arg(0))
  let srcLen = len(src)
  print("len=" + srcLen)
  let i = 0
  while i < 3 {
    print("i=" + i)
    let ch = src[i]
    print("ch=" + ch)
    i += 1
  }
  print("looped to i=" + i)
  emit "ok"
}
