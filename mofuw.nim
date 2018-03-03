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
  from posix import TCP_NODELAY, EAGAIN

from os import osLastError

import
  lib/httputils,
  lib/mofuparser,
  lib/jesterPatterns

export
  strtabs,
  httputils,
  asyncdispatch,
  jesterPatterns

type
  mofuwReq* = ref object
    line: HttpReq
    header: array[32, headers]
    headerAddr: ptr array[32, headers]
    body*: string
    params*: StringTableRef
    tmp*: cstring

  mofuwRes* = ref object
    fd: AsyncFD

  Callback = proc(req: mofuwReq, res: mofuwRes): Future[void]

const
  kByte* = 1024
  mByte* = 1024 * kByte

  defaultBufferSize = 8 * kByte
  maxBodySize = 1 * mByte

var
  cacheTables {.threadvar.}: TableRef[string, string]
  callback    {.threadvar.}: Callback
  bufferSize  {.threadvar.}: int

proc newServerSocket(port: int = 8080, backlog: int = 128): SocketHandle =
  let server = newSocket()

  server.setSockOpt(OptReuseAddr, true)

  server.setSockOpt(OptReusePort, true)

  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)

  server.getFd.setBlocking(false)

  server.bindAddr(Port(port))

  server.listen(backlog.cint)

  return server.getFd()

proc hash(str: string): Hash =
  var h = 0
  
  for v in str:
    h = h !& v.int

  result = !$h

proc getMethod*(req: mofuwReq): string {.inline.} =
  result = ($(req.line.method))[0 .. req.line.methodLen]

proc getPath*(req: mofuwReq): string {.inline.} =
  result = ($(req.line.path))[0 .. req.line.pathLen]

proc getCookie*(req: mofuwReq): string {.inline.} =
  for v in req.header:
    if v.name == nil: break
    if ($(v.name))[0 .. v.namelen] == "Cookie":
      result = ($(v.value))[0 .. v.valuelen]
      return
  result = ""

proc getHeader*(req: mofuwReq, name: string): string {.inline.} =
  for v in req.header:
    if v.name == nil: break
    if ($(v.name))[0 .. v.namelen] == name:
      result = ($(v.value))[0 .. v.valuelen]
      return
  result = ""

proc mofuwSend2*(res: mofuwRes, body: string) {.async.} =
  var
    buf: string

  shallowcopy(buf, body)

  when defined(windows):
    await send(res.fd, addr(buf[0]), buf.len)
  else:
    discard res.fd.SocketHandle.send(addr(buf[0]), buf.len, 0)

proc mofuwSend*(res: mofuwRes, body: string) {.async.}=
  var buf: string

  shallowcopy(buf, body)

  try:
    await send(res.fd, addr(buf[0]), buf.len)
  except:
    try:
      closeSocket(res.fd)
    except:
      discard

proc notFound*(res: mofuwRes) {.async.} =
  await mofuwSend(res, notFound())

include middleware/staticServe/mofuwStaticServe

proc cacheResp*(res: mofuwRes, path, status, mime, body: string) {.async.} =
  if cacheTables.hasKey(path):
    asyncCheck res.mofuwSend2(cacheTables[path])
    return
  else:
    let buf = makeResp(
      status,
      mime,
      body
    )

    asyncCheck res.mofuwSend2(buf)

    cacheTables[path] = buf

    proc cacheCB(fd: AsyncFD): bool =
      cacheTables[path] = makeResp(
        status,
        mime,
        body
      )
      result = false

    addTimer(1000, false, cacheCB)

when defined(windows):
  proc handler(fd: AsyncFD) {.async.} =
    while true:
      let recv = await recv(fd, bufferSize)

      if recv == "":
        try:
          closeSocket(fd)
        except:
          discard
        finally:
          break
      else:
        var
          buf = ""
          request = mofuwReq(body: "")
          response = mofuwRes(fd: fd)

        buf.add(recv)
        request.headerAddr = addr(request.header)

        if recv.len == bufferSize:
          while true:
            let recv = await recv(fd, bufferSize)

            if recv == "":
              break

          buf.add(recv)

        let r = mp_req(addr(buf[0]), request.line, request.headerAddr)

        if r <= 0:
          await response.mofuwSend(notFound())
          buf.setLen(0)

        request.body = $(addr(buf[r]))

        proc soon() =
          asyncCheck callback(request, response)
      
        callSoon(soon)
else:
  proc handler(fd: AsyncFD): bool =
    var
      bufSize = bufferSize
      buf = newString(bufSize)
      request = mofuwReq(body: "")
      response = mofuwRes(fd: fd)
  
    while true:
      let r = fd.SocketHandle.recv(addr(buf[0]), bufSize, 0)
  
      if r == 0:
        closeSocket(fd)
        return true
      elif r < 0:
        if osLastError().int in {EAGAIN}:
          break
        closeSocket(fd)
        return true
  
      request.body.add(addr(buf[0]))
  
    request.headerAddr = addr(request.header)
  
    let r = mp_req(addr(buf[0]), request.line, request.headerAddr)
  
    if r <= 0:
      asyncCheck response.mofuwSend(notFound())
      closeSocket(fd)
      return true
  
    request.body = $(addr(buf[r]))
  
    asyncCheck callback(request, response)
  
    return false

proc updateTime(fd: AsyncFD): bool =
  updateServerTime()
  return false

proc mofuwInit(port: int, backlog: int, bufSize: int, tables: TableRef[string, string]) {.async.} =

  let server = newServerSocket(port, backlog).AsyncFD

  bufferSize = bufSize

  cacheTables = tables

  register(server)

  addTimer(1000, false, updateTime)

  while true:
    let client = await accept(server)

    client.SocketHandle.setBlocking(false)

    when defined(windows):
      asyncCheck handler(client)
    else:
      addRead(client, handler)

proc run(port: int, backlog: int, bufSize: int, cb: Callback,
         tables: TableRef[string, string]) {.thread.} =
  callback = cb

  waitFor mofuwInit(port, backlog, bufSize, tables)

proc mofuwRun*(cb: Callback,
               port: int = 8080,
               backlog: int = SOMAXCONN,
               bufSize: int = defaultBufferSize) =

  if cb == nil:
    raise newException(Exception, "callback is nil.")

  cacheTables = newTable[string, string]()

  for i in 0 ..< countProcessors():
    spawn run(port, backlog, bufSize, cb, cacheTables)

  sync()

template mofuwResp*(status, mime, body: string): typed =
  asyncCheck res.mofuwSend2(makeResp(
    status,
    mime,
    body
  ))

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
        cmdName = body[i][0].ident.`$`.normalize.toUpperAscii()
        cmdPath = $body[i][1]

      if not methodTables.hasKey(cmdName):
        methodTables[cmdName] = newNimNode(nnkOfBranch)

        methodTables[cmdName].add(newLit(cmdName))

      if not caseTables.hasKey(cmdName):
        caseTables[cmdName] = newStmtList()

        caseTables[cmdName].add(
          newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("pat"), 
              ident("Pattern"),
              newNimNode(nnkEmpty)
            ),
            newNimNode(nnkIdentDefs).add(
              ident("re"), 
              newNimNode(nnkTupleTy).add(
                newNimNode(nnkIdentDefs).add(
                  ident("matched"), 
                  ident("bool"),
                  newNimNode(nnkEmpty)
                ),
                newNimNode(nnkIdentDefs).add(
                  ident("params"), 
                  ident("StringTableRef"),
                  newNimNode(nnkEmpty)
                )
              ),
              newNimNode(nnkEmpty)
            ),
            newNimNode(nnkIdentDefs).add(
              ident("path"), 
              newNimNode(nnkEmpty),
              newCall(
                "getPath",
                ident("req")
              )
            )
          ),
          newBlockStmt(
            ident("router"),
            newStmtList()
          )
        )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          ident("pat"),
          newCall(
            ident("parsePattern"),
            newStrLitNode(cmdPath)
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          ident("re"),
          newCall(
            ident("match"),
            ident("pat"),
            ident("path")
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          newDotExpr(
            ident("req"),
            ident("params")
          ),
          newDotExpr(
            ident("re"),
            ident("params")
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newIfStmt(
          (newDotExpr(
            ident("re"),
            ident("matched")
          ),
          body[i][2].add(
            parseStmt("break router")
          ))
        )
      )
    else:
      discard

  var
    nFound = newStmtList()
    elseMethod = newNimNode(nnkElse)

  nFound.add(
    newNimNode(nnkCommand).add(
      newIdentNode("asyncCheck"),
      newCall(
        "notFound",
        ident("res")
      )
    )
  )

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
    v.findChild(it.kind == nnkBlockStmt)[1].add(nFound)
    methodTables[k].add(v)

  for k, v in methodTables.pairs:
    methodCase.add(v)

  methodCase.add(elseMethod)

  result.add(methodCase)

macro routesStatic*(filePath: string, body: untyped): typed =
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
        cmdName = body[i][0].ident.`$`.normalize.toUpperAscii()
        cmdPath = $body[i][1]

      if not methodTables.hasKey(cmdName):
        methodTables[cmdName] = newNimNode(nnkOfBranch)

        methodTables[cmdName].add(newLit(cmdName))

      if not caseTables.hasKey(cmdName):
        caseTables[cmdName] = newStmtList()

        caseTables[cmdName].add(
          newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("pat"), 
              ident("Pattern"),
              newNimNode(nnkEmpty)
            ),
            newNimNode(nnkIdentDefs).add(
              ident("re"), 
              newNimNode(nnkTupleTy).add(
                newNimNode(nnkIdentDefs).add(
                  ident("matched"), 
                  ident("bool"),
                  newNimNode(nnkEmpty)
                ),
                newNimNode(nnkIdentDefs).add(
                  ident("params"), 
                  ident("StringTableRef"),
                  newNimNode(nnkEmpty)
                )
              ),
              newNimNode(nnkEmpty)
            ),
            newNimNode(nnkIdentDefs).add(
              ident("path"), 
              newNimNode(nnkEmpty),
              newCall(
                "getPath",
                ident("req")
              )
            )
          ),
          newBlockStmt(
            ident("router"),
            newStmtList()
          )
        )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          ident("pat"),
          newCall(
            ident("parsePattern"),
            newStrLitNode(cmdPath)
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          ident("re"),
          newCall(
            ident("match"),
            ident("pat"),
            ident("path")
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          newDotExpr(
            ident("req"),
            ident("params")
          ),
          newDotExpr(
            ident("re"),
            ident("params")
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newIfStmt(
          (newDotExpr(
            ident("re"),
            ident("matched")
          ),
          body[i][2].add(
            parseStmt("break router")
          ))
        )
      )
    else:
      discard

  var
    nFound = newStmtList()
    elseMethod = newNimNode(nnkElse)

  nFound.add(
    newNimNode(nnkVarSection).add(
      newNimNode(nnkIdentDefs).add(
        ident("fut"), 
        newNimNode(nnkEmpty),
        newCall(
          "serveStatic",
          ident("req"),
          ident("res"),
          newStrLitNode(strVal(filePath))
        )
      ),
    ),
    newAssignment(
      newDotExpr(
        ident("fut"),
        ident("callback")
      ),
      newNimNode(nnkLambda).add(
        newNimNode(nnkEmpty),
        newNimNode(nnkEmpty),
        newNimNode(nnkEmpty),
        newNimNode(nnkFormalParams).add(
          newNimNode(nnkEmpty)
        ),
        newNimNode(nnkEmpty),
        newNimNode(nnkEmpty),
        newStmtList().add(
          newNimNode(nnkIfStmt).add(
            newNimNode(nnkElifBranch).add(
              newNimNode(nnkPrefix).add(
                ident("not"),
                newDotExpr(
                  ident("fut"),
                  ident("read")
                )
              ),
              newStmtList().add(
                parseStmt("asyncCheck notFound(res)")
              )
            )
          )
        )
      )
    )
  )

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
    v.findChild(it.kind == nnkBlockStmt)[1].add(nFound)
    methodTables[k].add(v)

  for k, v in methodTables.pairs:
    methodCase.add(v)

  methodCase.add(elseMethod)

  result.add(methodCase)