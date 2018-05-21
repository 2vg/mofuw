import random, sequtils

randomize()

const allC = {'0'..'9', 'a'..'z', 'A'..'Z', '#', '$', '%', '.'}

var charArr: seq[char] = @[]

for v in allC:
  charArr.add($v)

proc randString*(len: int): string =
  result = ""

  for i in 1 .. len:
    shuffle(charArr)
    result.add($charArr[(rand(10000).int mod 66).int])

when isMainModule:
  echo randString(32)