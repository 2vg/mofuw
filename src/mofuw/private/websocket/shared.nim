import asyncdispatch, asyncnet, streams, nativesockets, strutils, tables,
  times, oids, random, options

type
  ProtocolError* = object of Exception

  Opcode* {.pure.} = enum
    Cont = 0x0 ## Continued Frame (when the previous was fin = 0)
    Text = 0x1 ## Text frames need to be valid UTF-8
    Binary = 0x2 ## Binary frames can be anything.
    Close = 0x8 ## Socket is being closed by the remote, or we intend to close it.
    Ping = 0x9 ## Ping
    Pong = 0xa ## Pong. Needs to echo back the app data in ping.

  Frame* = tuple
    ## A frame read off the netlayer.

    fin: bool ## Last frame in current packet.
    rsv1: bool ## Extension data: negotiated in http prequel, or 0.
    rsv2: bool ## Extension data: negotiated in http prequel, or 0.
    rsv3: bool ## Extension data: negotiated in http prequel, or 0.

    masked: bool ## If the frame was received masked/is supposed to be masked.
                 ## Do not mask data yourself.

    opcode: Opcode ## The opcode of this frame.

    data: string ## App data
  
  SocketKind* {.pure.} = enum
    Client, Server
  
  AsyncWebSocketObj = object of RootObj
    sock*: AsyncSocket
    protocol*: string
    kind*: SocketKind

  AsyncWebSocket* = ref AsyncWebSocketObj

proc htonll(x: uint64): uint64 =
  ## Converts 64-bit unsigned integers from host to network byte order.
  ## On machines where the host byte order is the same as network byte order,
  ## this is a no-op; otherwise, it performs a 8-byte swap operation.
  when cpuEndian == bigEndian: result = x
  else: result = (x shr 56'u64) or
                 (x shr 40'u64 and 0xff00'u64) or
                 (x shr 24'u64 and 0xff0000'u64) or
                 (x shr 8'u64 and 0xff000000'u64) or
                 (x shl 8'u64 and 0xff00000000'u64) or
                 (x shr 24'u64 and 0xff0000000000'u64) or
                 (x shl 40'u64 and 0xff000000000000'u64) or
                 (x shl 56'u64)

proc makeFrame*(f: Frame): string =
  ## Generate valid websocket frame data, ready to be sent over the wire.
  ## This is useful for rolling your own impl, for example
  ## with AsyncHttpServer

  var ret = newStringStream()

  var b0: byte = (f.opcode.byte and 0x0f)
  if f.fin: b0 = b0 or (1 shl 7)
  if f.rsv1: b0 = b0 or (1 shl 6)
  if f.rsv2: b0 = b0 or (1 shl 5)
  if f.rsv3: b0 = b0 or (1 shl 4)

  ret.write(b0)

  var b1: byte = 0

  let length = f.data.len
  if length <= 125: b1 = length.uint8
  elif length > 125 and length <= 0x7fff: b1 = 126u8
  else: b1 = 127u8

  let b1unmasked = b1
  if f.masked: b1 = b1 or (1 shl 7)

  ret.write(b1)

  if b1unmasked == 126u8:
    ret.write(length.uint16.htons)
  elif b1unmasked == 127u8:
    ret.write(length.uint64.htonll)

  var data = f.data

  if f.masked:
    # TODO: proper rng

    # for compatibility with renaming of random
    template rnd(x: untyped): untyped =
      when declared(random.rand):
        rand(x-1)
      else:
        random(x)

    randomize()
    let maskingKey = [ rnd(256).char, rnd(256).char,
      rnd(256).char, rnd(256).char ]

    for i in 0..<length: data[i] = (data[i].uint8 xor maskingKey[i mod 4].uint8).char

    ret.write(maskingKey)

  ret.write(data)
  ret.setPosition(0)
  result = ret.readAll()

  assert(result.len == (
    2 +
    (if f.masked: 4 else: 0) +
    (if b1unmasked == 126u8: 2 elif b1unmasked == 127u8: 8 else: 0) +
    length
  ))

proc makeFrame*(opcode: Opcode, data: string, masked: bool): string =
  ## A convenience shorthand.
  result = makeFrame((fin: true, rsv1: false, rsv2: false, rsv3: false,
    masked: masked, opcode: opcode, data: data))

proc recvFrame*(ws: AsyncSocket): Future[Frame] {.async.} =
  ## Read a full frame off the given socket.
  ##
  ## You probably want to use the higher-level variant, `readData`.

  const lookupTable = [128u8, 64, 32, 16, 8, 4, 2, 1]

  template `[]`(b: byte, idx: int): bool =
    (b and lookupTable[idx]) != 0

  var f: Frame
  let hdr = await ws.recv(2)
  if hdr.len != 2: raise newException(IOError, "socket closed")

  let b0 = hdr[0].uint8
  let b1 = hdr[1].uint8

  f.fin  = b0[0]
  f.rsv1 = b0[1]
  f.rsv2 = b0[2]
  f.rsv3 = b0[3]
  f.opcode = (b0 and 0x0f).Opcode

  if f.rsv1 or f.rsv2 or f.rsv3:
    raise newException(ProtocolError,
      "websocket tried to use non-negotiated extension")

  let hdrLen = int(b1 and 0x7f)
  let finalLen = case hdrLen:
    of 0x7e:
      var lenstr = await ws.recv(2, {})
      if lenstr.len != 2: raise newException(IOError, "socket closed")

      cast[ptr uint16](lenstr[0].addr)[].htons.int
    of 0x7f:
      var lenstr = await ws.recv(8, {})
      if lenstr.len != 8: raise newException(IOError, "socket closed")

      let realLen = cast[ptr uint64](lenstr[0].addr)[].htonll
      if realLen > high(int).uint64:
        raise newException(IOError, "websocket payload too large")

      realLen.int
    else: hdrLen

  f.masked = (b1 and 0x80) == 0x80
  var maskingKey = ""
  if f.masked:
    maskingKey = await ws.recv(4, {})
    # maskingKey = cast[ptr uint32](lenstr[0].addr)[]

  f.data = await ws.recv(finalLen, {})
  if f.data.len != finalLen: raise newException(IOError, "socket closed")

  if f.masked:
    for i in 0..<f.data.len:
      f.data[i] = (f.data[i].uint8 xor maskingKey[i mod 4].uint8).char

  result = f

proc extractCloseData*(data: string): tuple[code: int, reason: string] =
  ## A way to get the close code and reason out of the data of a Close opcode.
  let len = data.len
  var data = data
  result.code =
    if len >= 2:
      cast[ptr uint16](addr data[0])[].htons.int
    else:
      0
  result.reason = if len > 2: data[2..^1] else: ""

# Internal hashtable that tracks pings sent out, per socket.
# key is the socket fd
type PingRequest = Future[void] # tuple[data: string, fut: Future[void]]

var reqPing {.threadvar.}: Option[Table[int, PingRequest]]

proc readData*(ws: AsyncSocket, isClientSocket: bool):
    Future[tuple[opcode: Opcode, data: string]] {.async.} =

  ## Reads reassembled data off the websocket and give you joined frame data.
  ##
  ## Note: You will still see control frames, but they are all handled for you
  ## (Ping/Pong, Cont, Close, and so on).
  ##
  ## The only ones you need to care about are Opcode.Text and Opcode.Binary, the
  ## so-called application frames.
  ##
  ## As per the websocket specifications, all clients need to mask their responses.
  ## It is up to you to to set `isClientSocket` with a proper value, depending on
  ## if you are reading from a server or client socket.
  ##
  ## Will raise IOError when the socket disconnects and ProtocolError on any
  ## websocket-related issues.

  var resultData = ""
  var resultOpcode: Opcode

  if reqPing.isNone:
    reqPing = some(initTable[int, PingRequest]())

  var pingTable = reqPing.unsafeGet()

  while true:
    let f = await ws.recvFrame()
    # Merge sequentially read frames.
    resultData.add(f.data)

    case f.opcode
      of Opcode.Ping:
        await ws.send(makeFrame(Opcode.Pong, f.data, isClientSocket))

      of Opcode.Pong:
        if pingTable.hasKey(ws.getFD().AsyncFD.int):
          pingTable[ws.getFD().AsyncFD.int].complete()

        else: discard  # thanks, i guess?

      of Opcode.Cont:
        if not f.fin: continue

      of Opcode.Text, Opcode.Binary, Opcode.Close:
        resultOpcode = f.opcode
        # read another!
        if not f.fin: continue

      else:
        ws.close()
        raise newException(ProtocolError, "received invalid opcode: " & $f.opcode)

    # handle case: ping never arrives and client closes the connection
    if resultOpcode == Opcode.Close and pingTable.hasKey(ws.getFD().AsyncFD.int):
      let closeData = extractCloseData(resultData)
      let ex = newException(IOError, "socket closed while waiting for pong")
      if closeData.code != 0:
        ex.msg.add(", close code: " & $closeData.code)
      if closeData.reason != "":
        ex.msg.add(", reason: " & closeData.reason)
      pingTable[ws.getFD().AsyncFD.int].fail(ex)
      pingTable.del(ws.getFD().AsyncFD.int)

    return (resultOpcode, resultData)

proc sendText*(ws: AsyncSocket, p: string, masked: bool = false): Future[void] {.async.} =
  ## Sends text data. Will only return after all data has been sent out.
  await ws.send(makeFrame(Opcode.Text, p, masked))

proc sendBinary*(ws: AsyncSocket, p: string, masked: bool = false): Future[void] {.async.} =
  ## Sends binary data. Will only return after all data has been sent out.
  await ws.send(makeFrame(Opcode.Binary, p, masked))

proc sendPing*(ws: AsyncSocket, masked: bool = false, token: string = ""): Future[void] {.async.} =
  ## Sends a WS ping message.
  ## Will generate a suitable token if you do not provide one.

  let pingId = if token == "": $genOid() else: token
  await ws.send(makeFrame(Opcode.Ping, pingId, masked))

  # Old crud: send/wait. Very deadlocky.
  # let start = epochTime()
  # let pingId: string = $genOid()
  # var fut = newFuture[void]()
  # await ws.send(makeFrame(Opcode.Ping, pingId))
  # reqPing[ws.getFD().AsyncFD.int] = fut
  # echo "waiting"
  # await fut
  # reqPing.del(ws.getFD().AsyncFD.int)
  # result = ((epochTime() - start).float64 * 1000).int

proc readData*(ws: AsyncWebSocket): Future[tuple[opcode: Opcode, data: string]] =
  ## Reads reassembled data off the websocket and give you joined frame data.
  ##
  ## Note: You will still see control frames, but they are all handled for you
  ## (Ping/Pong, Cont, Close, and so on).
  ##
  ## The only ones you need to care about are Opcode.Text and Opcode.Binary, the
  ## so-called application frames.
  ##
  ## Will raise IOError when the socket disconnects and ProtocolError on any
  ## websocket-related issues.

  result = readData(ws.sock, ws.kind == SocketKind.Client)

proc sendText*(ws: AsyncWebSocket, p: string, masked: bool = false): Future[void] =
  ## Sends text data. Will only return after all data has been sent out.
  result = sendText(ws.sock, p, masked)

proc sendBinary*(ws: AsyncWebSocket, p: string, masked: bool = false): Future[void] =
  ## Sends binary data. Will only return after all data has been sent out.
  result = sendBinary(ws.sock, p, masked)

proc sendPing*(ws: AsyncWebSocket, masked: bool = false, token: string = ""): Future[void] =
  ## Sends a WS ping message.
  ## Will generate a suitable token if you do not provide one.
  result = sendPing(ws.sock, masked, token)

proc closeWebsocket*(ws: AsyncSocket, code = 0, reason = ""): Future[void] {.async.} =
  ## Closes the socket.

  defer: ws.close()

  var data = newStringStream()

  if code != 0:
    data.write(code.uint16)

  if reason != "":
    data.write(reason)

  await ws.send(makeFrame(Opcode.Close, data.readAll(), true))

proc close*(ws: AsyncWebSocket, code = 0, reason = ""): Future[void] =
  ## Closes the socket.
  result = ws.sock.closeWebsocket(code, reason)