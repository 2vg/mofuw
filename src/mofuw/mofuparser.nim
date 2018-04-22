const token = [
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,true ,true ,true ,true ,true ,true ,true ,
  false,false,true ,true ,false,true ,true ,false,
  true ,true ,true ,true ,true ,true ,true ,true ,
  true ,true ,false,false,false,false,false,false,
  false,true ,true ,true ,true ,true ,true ,true ,
  true ,true ,true ,true ,true ,true ,true ,true ,
  true ,true ,true ,true ,true ,true ,true ,true ,
  true ,true ,true ,false,false,false,true ,true ,
  true ,true ,true ,true ,true ,true ,true ,true ,
  true ,true ,true ,true ,true ,true ,true ,true ,
  true ,true ,true ,true ,true ,true ,true ,true ,
  true ,true ,true ,false,true ,false,true ,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false,
  false,false,false,false,false,false,false,false
]

const headerSize {.intdefine.} = 64

type
  MPHTTPReq* = ref object
    httpMethod*, path*, minor*: ptr char
    httpMethodLen*, pathLen*, headerLen*: int
    headers*: array[headerSize, headers]

  headers*     = object
    name*, value: ptr char
    nameLen*, valueLen*: int

proc getMethod*(req: MPHTTPReq): string {.inline.} =
  result = ($(req.httpMethod))[0 .. req.httpMethodLen]

proc getPath*(req: MPHTTPReq): string {.inline.} =
  result = ($(req.path))[0 .. req.pathLen]

proc getHeader*(req: MPHTTPReq, name: string): string {.inline.} =
  for i in 0 ..< req.headerLen:
    if ($(req.headers[i].name))[0 .. req.headers[i].namelen] == name:
      result = ($(req.headers[i].value))[0 .. req.headers[i].valuelen]
      return
  result = ""

iterator headersPair*(req: MPHTTPReq): tuple[name, value: string] =
  for i in 0 ..< req.headerLen:
    yield (($(req.headers[i].name))[0 .. req.headers[i].namelen],
           ($(req.headers[i].value))[0 .. req.headers[i].valuelen])

proc mpParseRequest*(req: ptr char, mhr: MPHTTPReq): int =

  # argment initialization
  mhr.httpMethod = nil
  mhr.path = nil
  mhr.minor = nil
  mhr.httpMethodLen = 0
  mhr.pathLen = 0
  mhr.headerLen = 0
  
  # address of first char of request char[]
  var buf = cast[int](req)
  
  # need headers object into array
  var hdlen = 0

  # METHOD check
  var start = buf
  while true:
    let uchar = cast[ptr char](buf)[]
    # nil check
    if uchar == '\0':
      return -1
    # space chck
    elif uchar == '\32':
      buf += 1
      break
    # non printable check
    elif uchar < '\32' or uchar > '\127':
      return -1
    else:
      buf += 1

  mhr.httpMethod = cast[ptr char](start)
  mhr.httpMethodLen = buf - start - 2

  # PATH check
  start = buf
  while true:
    let uchar = cast[ptr char](buf)[]
    # nil check
    if uchar == '\0':
      return -1
    # space chck
    elif uchar == '\32':
      buf += 1
      break
    # non printable check
    elif uchar < '\32' or uchar > '\127':
      return -1
    else:
      buf += 1

  mhr.path = cast[ptr char](start)
  mhr.pathLen = buf - start - 2

  # HTTP Version check
  # 'H' check
  if not(cast[ptr char](buf)[] == '\72'):
    return -1
  buf += 1

  # 'T' check
  if not(cast[ptr char](buf)[] == '\84'):
    return -1
  buf += 1

  # 'T' check
  if not(cast[ptr char](buf)[] == '\84'):
    return -1
  buf += 1

  # 'P' check
  if not(cast[ptr char](buf)[] == '\80'):
    return -1
  buf += 1

  # '/' check
  if not(cast[ptr char](buf)[] == '\47'):
    return -1
  buf += 1

  # '1' check
  if not(cast[ptr char](buf)[] == '\49'):
    return -1
  buf += 1

  # '.' check
  if not(cast[ptr char](buf)[] == '\46'):
    return -1
  buf += 1

  # numeric check
  if 47 < cast[ptr char](buf)[].int or cast[ptr char](buf)[].int < 58:
    mhr.minor = cast[ptr char](buf)
  else:
    return -1

  buf += 1

  # HEADER check
  for i in 0 ..< mhr.headers.len:
    let uchar = cast[ptr char](buf)[]
    # nil check
    if uchar == '\0':
      return -1
    # CR check
    elif uchar == '\13':
      buf += 1
      # LF check
      if not(cast[ptr char](buf)[] == '\10'):
        return -1
      buf += 1
      # if second CR, request will end
      if cast[ptr char](buf)[] == '\13':
        buf += 1
        # if second LF check is true, request is end or next is body.
        if not(cast[ptr char](buf)[] == '\10'):
          return -1
        break
    # LF check
    elif uchar == '\10':
      if cast[ptr char](buf)[] == '\10':
        break
      buf += 1
    # non space and non tab check
    elif not(uchar == '\32') and not(uchar == '\9'):
      # HEADER key check
      start = buf
      mhr.headers[hdlen].name = cast[ptr char](start)

      while true:
        let uchar = cast[ptr char](buf)[]
        # nil check
        if uchar == '\0':
          return -1
        # space check
        elif uchar == '\32':
          return -1
        # colon check
        elif uchar == '\58':
          mhr.headers[hdlen].nameLen = buf - start - 1
          buf += 1
          if cast[ptr char](buf)[] == '\32':
            mhr.headers[hdlen].nameLen = buf - start - 2
            buf += 1
          break
        # token check
        elif not token[uchar.int]:
          return -1
        else:
          buf += 1

      # HEADER value check
      start = buf
      mhr.headers[hdlen].value = cast[ptr char](start)

      while true:
        let uchar = cast[ptr char](buf)[]
        # nil check
        if uchar == '\0':
          return -1
        # non printable check
        elif (uchar.int < 32) and not(uchar == '\9') or uchar == '\127':
          # if CR, header line will end
          if uchar == '\13':
            break
          elif uchar == '\10':
            break
          else:
            return -1
        else:
          buf += 1

      mhr.headers[hdlen].valueLen = buf - start - 1
      hdlen += 1

  mhr.headerLen = hdlen
  return buf - cast[int](req) + 1

# test
when isMainModule:
  import times

  var 
    test = "GET /test HTTP/1.1\r\LHost: 127.0.0.1:8080\r\LConnection: keep-alive\r\LCache-Control: max-age=0\r\LAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\LUser-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.56 Safari/537.17\r\LAccept-Encoding: gzip,deflate,sdch\r\LAccept-Language: en-US,en;q=0.8\r\LAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\LCookie: name=mofuparser\r\L\r\Ltest=hoge"

    mpr = MPHTTPReq()

  # for benchmark (?) lol
  let old = cpuTime()
  for i in 0 .. 100000:
    discard mpParseRequest(test[0].addr, mpr)
  echo cpuTime() - old

  if mpParseRequest(test[0].addr, mpr) > 0:
    echo mpr.getMethod
    echo mpr.getPath
    echo ($(mpr.minor))[0]
    for name, value in mpr.headersPair:
      echo "name: " & name & " | value: " & value
  else:
    echo "invalid request."