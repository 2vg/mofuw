import
  net,
  hashes,
  macros,
  osproc,
  tables,
  strtabs,
  strutils,
  threadpool,
  asyncdispatch,
  nativesockets

when defined(windows):
  from winlean import TCP_NODELAY
else:
  from posix import TCP_NODELAY

import
  lib/httputils,
  lib/mofuparser,
  lib/objectPool

export asyncdispatch
export httputils

type
  mofuwReq* = ref object
    reqLine: HttpReq
    reqHeader*: array[16, headers]
    reqHeaderAddr: ptr array[16, headers]
    reqBody*: string
    reqBodyLen: int
    params*: StringTableRef
    tmp*: cstring

  mofuwRes* = ref object
    fd: AsyncFD

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
        buf = ""
        request = mofuwReq(reqBody: "")
        response = mofuwRes()

      buf.add(recv)
      request.reqHeaderAddr = request.reqHeader.addr

      response.fd = fd

      if recv.len == bufferSize:
        while true:
          let recv = await recv(fd, bufferSize)

          if recv == "":
            break

          buf.add(recv)

      let r = mp_req(addr(buf[0]), request.reqLine, request.reqHeaderAddr)

      if r <= 0:
        await response.mofuwSend(notFound())
        buf.setLen(0)

      shallowcopy(request.reqBody, buf[r .. buf.len - 1])
      request.reqBodyLen = request.reqBody.len

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

proc hash(str: string): Hash =
  var h = 0
  
  for v in str:
    h = h !& v.int

  result = !$h

proc create(body, stmt: NimNode, i: int) {.compileTime.} =
  stmt.add(body[i][2])

macro routes*(body: untyped): typed =
  result = newStmtList()

  var
    methodCase = newNimNode(nnkCaseStmt)
    methodTables = initTable[string, NimNode]()
    caseTables = initTable[string, NimNode]()

  methodCase.add(
    newCall(
      "getMethod",
      ident("req")
    )
  )

  for i in 0 ..< body.len:
    case body[i].kind
    of nnkCommand:
      let
        cmdName = body[i][0].ident.`$`.normalize.toUpper()
        cmdPath = $body[i][1]

      if not methodTables.hasKey(cmdName):
        methodTables[cmdName] = newNimNode(nnkOfBranch)

        methodTables[cmdName].add(newLit(cmdName))

      if not caseTables.hasKey(cmdName):
        caseTables[cmdName] = newNimNode(nnkCaseStmt)
      
        caseTables[cmdName].add(
          newCall(
            "getPath",
            ident("req")
          )
        )

      var stmt = newNimNode(nnkOfBranch)
      stmt.add(newLit(cmdPath))
      create(body, stmt, i)
      caseTables[cmdName].add(stmt)
    else:
      discard

  var elseMethod = newNimNode(nnkElse)

  elseMethod.add(
    newStmtList(
      newNimNode(nnkCommand).add(
        newIdentNode("asyncCheck"),
        newCall(
          "notFound",
          ident("res")
        )
      )
    )
  )

  for k, v in caseTables.pairs:
    v.add(elseMethod)
    methodTables[k].add(v)

  for k, v in methodTables.pairs:
    methodCase.add(v)

  methodCase.add(elseMethod)

  result.add(methodCase)

  dumpAstGen:
    mofuw.callback = proc(req: mofuwReq, res: mofuwRes) {.async.} =
      await call("test")