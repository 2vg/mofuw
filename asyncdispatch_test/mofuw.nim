import asyncdispatch, net, nativesockets, threadpool, osproc, strtabs

when defined(windows):
  from winlean import TCP_NODELAY, WSAEWOULDBLOCK

  const
    EAGAIN = WSAEWOULDBLOCK
    EWOULDBLOCK = WSAEWOULDBLOCK
else:
  from posix import TCP_NODELAY

import lib/httputils
import lib/mofuparser

export asyncdispatch
export httputils

type
  mofuwReq* = ref object
    reqLine: HttpReq
    reqHeader*: array[48, headers]
    reqHeaderAddr: ptr array[48, headers]
    reqBody*: string
    reqBodyLen*: int
    params*: StringTableRef
    tmp*: cstring
  
  mofuwRes* = ref object
    fd: AsyncFD
    req: mofuwReq
  
  Callback* = proc(req: mofuwReq, res: mofuwRes): Future[void]

const
  kByte* = 1024
  mByte* = 1024 * kByte

  defaultBufferSize = 8 * kByte
  maxBodySize = 1 * mByte

var
  callback*    {.threadvar.}: Callback
  bufferSize*  {.threadvar.}: int

proc newServerSocket(port: int = 8080, backlog: int = 128): SocketHandle =
  let server = newSocket()

  server.setSockOpt(OptReuseAddr, true)

  server.setSockOpt(OptReusePort, true)

  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)

  server.getFd.setBlocking(false)

  server.bindAddr(Port(port))

  server.listen(backlog.cint)

  return server.getFd()

proc getMethod*(req: mofuwReq): string {.inline.} =
  result = ($(req.reqLine.method))[0 .. req.reqLine.methodLen]

proc getPath*(req: mofuwReq): string {.inline.} =
  result = ($(req.reqLine.path))[0 .. req.reqLine.pathLen]

proc getCookie*(req: mofuwReq): string {.inline.} =
  for v in req.reqHeader:
    if v.name == nil: break
    if ($(v.name))[0 .. v.namelen] == "Cookie":
      result = ($(v.value))[0 .. v.valuelen]
      return
  result = ""

proc getReqBody*(req: mofuwReq): string {.inline.} =
  result = $req.reqBody

proc mofuwSend*(res: mofuwRes, body: string) {.async.}=
  await send(res.fd, body)

proc notFound*(res: mofuwRes) {.async.} =
  await mofuwSend(res, notFound())

proc handler(fd: AsyncFD) {.async.} =
  while true:
    let recv = await recv(fd, bufferSize)

    if recv == "":
      closeSocket(fd)
      break
    else:
      var
        request = mofuwReq(reqBody: "")
        response = mofuwRes()

      request.reqBody.add(recv)
      request.reqHeaderAddr = request.reqHeader.addr

      response.fd = fd

      if recv.len == bufferSize:
        while true:
          let recv = await recv(fd, bufferSize)

          if recv == "":
            break

          request.reqBody.add(recv)

      let r = mp_req(addr(request.reqBody[0]), request.reqLine, request.reqHeaderAddr)

      if r <= 0:
        await response.mofuwSend(notFound())
        request.reqBody.setLen(0)

      await callback(request, response)

proc updateTime(fd: AsyncFD): bool =
  updateServerTime()
  return false

proc mofuwInit(port: int, backlog: int, bufSize: int) {.async.} =

  let server = newServerSocket(port, backlog).AsyncFD

  bufferSize = bufSize

  register(server)

  addTimer(1000, false, updateTime)

  while true:
    let client = await accept(server)

    client.SocketHandle.setBlocking(false)

    asyncCheck handler(client)

proc run(port: int, backlog: int, bufSize: int, cb: Callback) {.thread.} =
  callback = cb

  waitFor mofuwInit(port, backlog, bufSize)

proc mofuwRun*(port: int = 8080, backlog: int = SOMAXCONN,
              bufSize: int = defaultBufferSize) =

  if callback == nil:
    raise newException(Exception, "callback is nil.")

  for i in 0 ..< countProcessors():
    spawn run(port, backlog, bufSize, callback)

  sync()