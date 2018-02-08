import sysrand, random, sequtils

randomize()

const allC = {'0'..'9', 'a'..'z', 'A'..'Z', '$'}

var charArr: seq[char] = @[]

for v in allC:
  charArr.add($v)

proc randString*(len: int): string =
  result = ""

  for i in 1 .. len:
    shuffle(charArr)
    result.add($charArr[(getRandom(10000 mod 63)).int])

when isMainModule:
  echo randString(32)