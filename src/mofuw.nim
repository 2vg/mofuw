import
  net,
  uri,
  json,
  times,
  hashes,
  macros,
  osproc,
  tables,
  logging,
  strtabs,
  strutils,
  asyncnet,
  asyncfile,
  strformat,
  threadpool,
  asyncdispatch,
  nativesockets

from httpcore import HttpHeaders

when defined(windows):
  from winlean import TCP_NODELAY, WSAEWOULDBLOCK
else:
  from posix import TCP_NODELAY, EAGAIN, EWOULDBLOCK

when defined(linux):
  from posix import Pid
  const TCP_FASTOPEN = 23.cint

from os import osLastError

import
  mofuparser,
  mofuhttputils,
  mofuw/nest,
  mofuw/jesterUtils

export
  uri,
  nest,
  strtabs,
  mofuhttputils,
  asyncdispatch

type
  mofuwReq* = ref object
    client*: AsyncSocket
    mhr: MPHTTPReq
    ip*: string
    buf*: string
    bodyStart: int
    bodyParams, uriParams, uriQuerys: StringTableRef
    # this is for big request
    # TODO
    tmp*: cstring

  mofuwRes* = ref object
    fd*: AsyncFD

  Callback = proc(req: mofuwReq, res: mofuwRes): Future[void]

const
  kByte = 1024
  mByte = 1024 * kByte

  defaultBufferSize = 8 * kByte
  defaultMaxBodySize {.intdefine.} = 1 * mByte
  bufSize {.intdefine.} = 512

  isDebug {.intdefine.} = if defined(release) or defined(safeRelease): 1 else: 0

var cacheTables {.threadvar, deprecated.}: TableRef[string, string]
var callback {.threadvar.}: Callback
var serverPort {.threadvar.}: int
var maxBodySize {.threadvar.}: int
var errorLogFile {.threadvar.}, accessLogFile {.threadvar.}: AsyncFile

proc countCPUs: int =
  when defined(linux):
    const
      schedh = "#define _GNU_SOURCE\n#include <sched.h>"
    type CpuSet {.importc: "cpu_set_t", header: schedh.} = object
      when defined(linux) and defined(amd64):
        abi: array[1024 div (8 * sizeof(culong)), culong]
    var set: CpuSet
    proc sched_getAffinity(pid: Pid, cpusetsize: int, mask: var CpuSet): cint {.
      importc: "sched_getaffinity", header: schedh.}
    proc cpusetCount(s: var CpuSet): int {. importc: "CPU_COUNT", header: schedh.}
    if sched_getAffinity(0, sizeof(CpuSet), set) == 0.cint:
      return cpusetCount(set)
    else:
      return countProcessors()
  else:
    return countProcessors()

proc defaultBacklog: int =
  when defined(linux):
    proc fscanf(c: File, frmt: cstring): cint
      {.varargs, importc, header: "<stdio.h>".}

    var
      backlog: int = SOMAXCONN
      f: File
      tmp: int

    if f.open("/proc/sys/net/core/somaxconn"): # See `man 2 listen`.
      if fscanf(f, "%d", tmp.addr) == cint(1):
        backlog = tmp
      f.close
    return backlog
  else:
    return SOMAXCONN

proc newServerSocket(port: int = 8080, backlog: int = 128): SocketHandle =
  let server = newSocket()

  server.setSockOpt(OptReuseAddr, true)

  server.setSockOpt(OptReusePort, true)

  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)

  when defined(linux):
    server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_FASTOPEN, 256)

  server.getFd.setBlocking(false)

  server.bindAddr(Port(port))

  server.listen(backlog.cint)

  return server.getFd()

proc getMethod*(req: mofuwReq): string {.inline.} =
  result = getMethod(req.mhr)

proc getPath*(req: mofuwReq): string {.inline.} =
  result = getPath(req.mhr)

proc getCookie*(req: mofuwReq): string {.inline.} =
  result = getHeader(req.mhr, "Cookie")

proc getHeader*(req: mofuwReq, name: string): string {.inline.} =
  result = getHeader(req.mhr, name)

proc toHttpHeaders*(req: mofuwReq): HttpHeaders {.inline.} =
  result = req.mhr.toHttpHeaders()

proc setParam*(req: mofuwReq, params: StringTableRef) {.inline.} =
  req.uriParams = params

proc setQuery*(req: mofuwReq, query: StringTableRef) {.inline.} =
  req.uriQuerys = query

proc params*(req: mofuwReq, key: string): string =
  if req.uriParams.isNil: return nil
  req.uriParams.getOrDefault(key)

proc query*(req: mofuwReq, key: string): string =
  if req.uriQuerys.isNil: return nil
  req.uriQuerys.getOrDefault(key)

proc body*(req: mofuwReq, key: string = nil): string =
  if key.isNil: return $req.buf[req.bodyStart .. ^1]
  if req.bodyParams.isNil: req.bodyParams = req.body.bodyParse
  req.bodyParams.getOrDefault(key)

proc hash(str: string): Hash =
  var h = 0
  for v in str:
    h = h !& v.int
  result = !$h

proc mofuwSend*(res: mofuwRes, body: string) {.async.} =
  var buf: string
  shallowcopy(buf, body)

  # try send because raise exception.
  # buffer not protect, but
  # mofuwReq have buffer, so this is safe.(?)
  let fut = send(res.fd, addr(buf[0]), buf.len)
  yield fut
  if fut.failed:
    try:
      closeSocket(res.fd)
    except:
      # TODO send error logging
      discard

template mofuwResp*(status, mime, body: string): typed =
  asyncCheck res.mofuwSend(makeResp(
    status,
    mime,
    body))

template mofuwOK*(body: string, mime: string = "text/plain") =
  mofuwResp(
    HTTP200,
    mime,
    body)

proc cacheResp*(res: mofuwRes, path, status, mime, body: string) {.async, deprecated.} =
  if cacheTables.hasKey(path):
    asyncCheck res.mofuwSend(cacheTables[path])
    return
  else:
    let buf = makeResp(
      status,
      mime,
      body
    )

    asyncCheck res.mofuwSend(buf)

    cacheTables[path] = buf

    proc cacheCB(fd: AsyncFD): bool =
      cacheTables[path] = makeResp(
        status,
        mime,
        body
      )
      result = false

    addTimer(1000, false, cacheCB)

proc notFound*(res: mofuwRes) {.async.} =
  await mofuwSend(res, notFound())

proc badGateway: string =
  result = makeResp(
    HTTP502,
    "text/plain",
    "502 Bad Gateway")

proc nowDateTime: (string, string) =
  var ti = now()
  result = 
    ($ti.year & '-' & intToStr(ord(ti.month), 2) &
    '-' & intToStr(ti.monthday, 2),
    intToStr(ti.hour, 2) & ':' & intToStr(ti.minute, 2) &
    ':' & intToStr(ti.second, 2))

proc serverLogging*(req: mofuwReq, format: string = nil) =
  let (date, time) = nowDateTime()
  if format.isNil:
    var log = %*{
      "address": req.ip,
      "request_method": req.getMethod,
      "request_path": req.getPath,
      "date": date,
      "time": time,
    }

proc serverError*(res: mofuwRes): string =
  let exp = getCurrentException()
  let stackTrace = exp.getStackTrace()
  result = $exp.name & ": " & exp.msg & "\n" & stackTrace

proc doubleCRLFCheck(req: var mofuwReq): int =
  let bodyStart = mpParseRequest(addr req.buf[0], req.mhr)

  let hMethod =
    if not req.mhr.httpMethod.isNil: req.getMethod
    else: ""

  if likely(hMethod == "GET" or hMethod == "HEAD"):
    if req.buf[^1] == '\l' and req.buf[^2] == '\r' and
       req.buf[^3] == '\l' and req.buf[^4] == '\r':
      req.bodyStart = bodyStart; return 0
    else: return -1
  else:
    if unlikely(hMethod == ""):
      template lenCheck(str: string, idx: int): char =
        if idx > str.len - 1: '\0'
        else: str[idx]
      for i, ch in req.buf:
        if ch == '\r':
          if req.buf.lenCheck(i+1) == '\l' and
             req.buf.lenCheck(i+2) == '\r' and
             req.buf.lenCheck(i+3) == '\l':
            return -3
      return -1

    if unlikely(req.buf.len - bodyStart > maxBodySize):
      return -2
    else:
      if likely(bodyStart > 0): req.bodyStart = bodyStart; return 0
      else: return -1

proc handler(fd: AsyncFD, ip: string) {.async.} =
  var
    request = mofuwReq(client: newAsyncSocket(fd), buf: "", mhr: MPHTTPReq())
    response = mofuwRes(fd: fd)
    r: int
    buf: array[bufSize, char]
    bigBuf: array[bufSize*2, char]

  block handler:
    while true:
      # using our buffer
      r = await recvInto(fd, addr buf[0], bufSize)

      if r == 0: closeSocket(fd); return

      let ol = request.buf.len
      request.buf.setLen(ol+r)
      copyMem(addr request.buf[ol], addr buf[0], r)

      case request.doubleCRLFCheck()
      of 0:
        let isGETorHEAD = (request.getMethod == "GET") or (request.getMethod == "HEAD")

        # for not GET or HEAD METHOD
        if not isGETorHEAD:
          let cLenHeader = request.getHeader("Content-Length")
          if cLenHeader != "":
            let cLen =
              try:
                parseInt(cLenHeader)
              except:
                -1
            if cLen != -1:
              while request.buf.len - request.bodyStart != cLen:
                r = await recvInto(fd, addr buf[0], bufSize)
                if r == 0: closeSocket(fd); return
                let ol = request.buf.len
                request.buf.setLen(ol+r)
                copyMem(addr request.buf[ol], addr buf[0], r)
            else:
              # TODO: Content-Length error.
              discard
          # TODO: suppoer chunk.
          #elif request.getHeader("Transfer-Chunked-Encode") != "":
            # do
          else:
            await response.mofuwSend(badRequest())
            closeSocket(fd)
            break handler

          # If the request body is large,
          # there is a possibility that
          # the pointer of the buffer has been changed by setLen.
          # So reparse the pointers up to \r\l\r\l.
          discard mpParseRequest(addr request.buf[0], request.mhr)

        # our callback check.
        try:
          # TODO: timeout
          await callback(request, response)
        except:
          # TODO: error check.
          let fut = response.mofuwSend(badGateway())
          fut.callback = proc() =
            closeSocket(response.fd)
          break handler

        # for pipeline ?
        request.buf.delete(0, request.bodyStart)

        var remainingBufferSize = request.buf.len

        while true:
          if unlikely(isGETorHEAD and (remainingBufferSize > 0)):
            let r = request.doubleCRLFCheck()

            if r <= 0:
              break

            request.bodyStart = r

            try:
              # TODO: timeout.
              await callback(request, response)
            except:
              # TODO: error check.
              let fut = response.mofuwSend(badGateway())
              fut.callback = proc() =
                closeSocket(response.fd)
              break handler
            remainingBufferSize = request.buf.len - request.bodyStart - 1
          else:
            request.buf.setLen(0)
            break

      of -1: continue
      of -2:
        await response.mofuwSend(bodyTooLarge())
        closeSocket(fd)
        break handler
      of -3:
        await response.mofuwSend(badRequest())
        closeSocket(fd)
        break handler
      else: discard

proc updateTime(fd: AsyncFD): bool =
  updateServerTime()
  return false

proc mofuwInit(port, mBodySize: int;
               tables: TableRef[string, string]) {.async.} =
  let server = newServerSocket(port, defaultBacklog()).AsyncFD
  maxBodySize = mBodySize
  cacheTables = tables
  register(server)
  updateServerTime()
  addTimer(1000, false, updateTime)

  var cantAccept = false
  while true:
    if unlikely cantAccept:
      await sleepAsync(10)
      cantAccept = false

    try:
      let data = await acceptAddr(server)
      let (address, client) = data
      client.SocketHandle.setBlocking(false)
      # handler error check.
      asyncCheck handler(client, address)
    except:
      # TODO async sleep.
      # await sleepAsync(10)
      cantAccept = true

proc run(port, maxBodySize: int;
         cb: Callback, tables: TableRef[string, string]) {.thread.} =

  callback = cb
  waitFor mofuwInit(port, maxBodySize, tables)

proc setCallback*(cb: Callback) =
  callback = cb

proc setPort*(port: int) =
  serverPort = port

proc setMaxBodySize*(port: int) =
  serverPort = port

proc mofuwRun*(port: int = 8080,
               maxBodySize: int = defaultMaxBodySize) =

  if callback == nil:
    raise newException(Exception, "callback is nil.")

  #if isDebug.bool:
  #  errorLogFile = openAsync("error.log")
  #  accessLogFile = openAsync("access.log")

  cacheTables = newTable[string, string]()

  for i in 0 ..< countCPUs():
    spawn run(port, maxBodySize, callback, cacheTables)

  sync()

proc mofuwRun*(cb: Callback,
               port: int = 8080,
               maxBodySize: int = defaultMaxBodySize) =

  if cb == nil:
    raise newException(Exception, "callback is nil.")

  #if isDebug.bool:
  #  errorLogFile = openAsync("error.log")
  #  accessLogFile = openAsync("access.log")

  cacheTables = newTable[string, string]()

  for i in 0 ..< countCPUs():
    spawn run(port, maxBodySize, cb, cacheTables)

  sync()

macro mofuwHandler*(body: untyped): untyped =
  result = newStmtList()

  let lam = newNimNode(nnkProcDef).add(
    ident"mofuwHandler",newEmptyNode(),newEmptyNode(),
    newNimNode(nnkFormalParams).add(
      newEmptyNode(),
      newIdentDefs(ident"req", ident"mofuwReq"),
      newIdentDefs(ident"res", ident"mofuwRes")
    ),
    newNimNode(nnkPragma).add(ident"async"),
    newEmptyNode(),
    body
  )

  result.add(lam)

macro mofuwLambda(body: untyped): untyped =
  result = newStmtList()

  let lam = newNimNode(nnkLambda).add(
    ident"mofuwHandler",newEmptyNode(),newEmptyNode(),
    newNimNode(nnkFormalParams).add(
      newEmptyNode(),
      newIdentDefs(ident"req", ident"mofuwReq"),
      newIdentDefs(ident"res", ident"mofuwRes")
    ),
    newNimNode(nnkPragma).add(ident"async"),
    newEmptyNode(),
    body
  )

  result.add(lam)

macro routes*(body: untyped): untyped =
  result = newStmtList()
  result.add(parseStmt("""
    let mofuwRouter = newRouter[proc(req: mofuwReq, res: mofuwRes): Future[void]]()
  """))

  # mofuwRouter.map(
  #   proc(req: mofuwReq, res: mofuwRes) {.async.} =
  #     body
  # , "METHOD", "PATH")
  for i in 0 ..< body.len:
    case body[i].kind
    of nnkCommand:
      let methodName = ($body[i][0]).normalize.toLowerAscii()
      let pathName = $body[i][1]
      result.add(
        newCall("map", ident"mofuwRouter",
          getAst(mofuwLambda(body[i][2])),
          newLit(methodName),
          newLit(pathName)
        )
      )
    else:
      discard

  result.add(newCall(ident"compress", ident"mofuwRouter"))

  let handlerBody = newStmtList()

  handlerBody.add(
    parseStmt"""
    var headers = req.toHttpHeaders()
    """,
    parseStmt"""
    let r = mofuwRouter.route(req.getMethod, parseUri(req.getPath), headers)
    """
  )

  # if r.status == routingFailure:
  #   await res.mofuwSned(notFound())
  # else:
  #   req.setParam(r.arguments.pathArgs)
  #   req.setQuery(r.arguments.queryArgs)
  #   await r.handler(req, res)
  handlerBody.add(
    newNimNode(nnkIfStmt).add(
      newNimNode(nnkElifBranch).add(
        infix(
          newDotExpr(ident"r", ident"status"),
          "==",
          ident"routingFailure"
        ),
        newStmtList().add(
          newNimNode(nnkCommand).add(
            ident"await",
            newCall(
              newDotExpr(ident"res", ident"mofuwSend"),
              newCall("notFound")
            )
          )
        )
      ),
      newNimNode(nnkElse).add(
        newStmtList(
          newCall(
            newDotExpr(ident"req", ident"setParam"),
            newDotExpr(newDotExpr(ident"r", ident"arguments"), ident"pathArgs")
          ),
          newCall(
            newDotExpr(ident"req", ident"setQuery"),
            newDotExpr(newDotExpr(ident"r", ident"arguments"), ident"queryArgs")
          ),
          newNimNode(nnkCommand).add(
            ident"await",
            newCall(
              newDotExpr(ident"r", ident"handler"),
              ident"req", ident"res"
            )
          )
        )
      )
    )
  )

  result.add(getAst(mofuwHandler(handlerBody)))

  result.add(parseStmt("""
    setCallback(mofuwHandler)
  """))
