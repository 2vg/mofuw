import times
template Ptr*(body: untyped) =
  template `+`*[T](p: ptr T, off: int): ptr T =
    cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))
  
  template `+=`*[T](p: ptr T, off: int) =
    p = p + off
  
  template `-`*[T](p: ptr T, off: int): ptr T =
    cast[ptr type(p[])](cast[ByteAddress](p) -% off * sizeof(p[]))
  
  template `-=`*[T](p: ptr T, off: int) =
    p = p - off
  
  template `[]`*[T](p: ptr T, off: int): T =
    (p + off)[]
  
  template `[]=`*[T](p: ptr T, off: int, val: T) =
    (p + off)[] = val
  
  body

var
  cnt = 0
  ch: array[7 * 1_000_000, char]
  chaddr = addr(ch[0])

var o = cpuTime()

var
  str = ""
  i = uint(0)

while uint(1_000_000) > i:
  str.add($i)
  str.add("\n")
  i.inc
  str.add($i)
  str.add("\n")
  i.inc
  str.add("Fizz\n")
  i.inc
  str.add($i)
  str.add("\n")
  i.inc
  str.add("Buzz\n")
  i.inc
  str.add("Fizz\n")
  i.inc
  str.add($i)
  str.add("\n")
  i.inc
  str.add($i)
  str.add("\n")
  i.inc
  str.add("Fizz\n")
  i.inc
  str.add("Buzz\n")
  i.inc
  str.add($i)
  str.add("\n")
  i.inc
  str.add("Fizz\n")
  i.inc
  str.add($i)
  str.add("\n")
  i.inc
  str.add($i)
  str.add("\n")
  i.inc
  str.add("FizzBuzz\n")
  i.inc

#echo addr(ch[0])
echo cpuTime() - o