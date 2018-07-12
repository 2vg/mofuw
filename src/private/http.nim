import core, io
import mofuparser, mofuhttputils
import os, macros, strutils, mimetypes, asyncdispatch, asyncfile

type
  ReqState* = enum
    badReq = -3,
    bodyLarge,
    continueReq,
    endReq

# ##
# return ReqState
# ##
proc doubleCRLFCheck*(req: mofuwReq): ReqState =
  # ##
  # parse request
  # ##
  let bodyStart = mpParseRequest(addr req.buf[0], req.mhr)

  # ##
  # found HTTP Method, return
  # not found, 0 length string
  # ##
  let hMethod =
    if not req.mhr.httpMethod.isNil: req.getMethod
    else: ""

  if likely(hMethod == "GET" or hMethod == "HEAD"):
    # ##
    # check \r\l\r\l
    # ##
    if req.buf[^1] == '\l' and req.buf[^2] == '\r' and
       req.buf[^3] == '\l' and req.buf[^4] == '\r':
      # ##
      # if not bodyStart > 0, request is invalid.
      # ##
      if likely(bodyStart != -1):
        req.bodyStart = bodyStart
        return endReq
      else:
        return badReq
    # ##
    # if not end \r\l\r\l, the request may be in progress
    # ##
    else: return continueReq
  else:
    if unlikely(hMethod == ""):
      template lenCheck(str: string, idx: int): char =
        if idx > str.len - 1: '\0'
        else: str[idx]

      # ##
      # very slow \r\l\r\l check
      # ##
      for i, ch in req.buf:
        if ch == '\r':
          if req.buf.lenCheck(i+1) == '\l' and
             req.buf.lenCheck(i+2) == '\r' and
             req.buf.lenCheck(i+3) == '\l':
            # ##
            # Even if it ends with \r\l\r\l,
            # it is an illegal request because the method is empty
            # ##
            return badReq

      # ##
      # if the method is empty and does not end with \r\l\r\l,
      # the request may be in progress
      # for example, send it one character at a time (telnet etc.)
      # G -> E -> T
      # ##
      return continueReq

    # ##
    # req.buf.len - bodyStart = request body size
    # ##
    if unlikely(req.buf.len - bodyStart > getMaxBodySize()):
      return bodyLarge
    else:
      # ##
      # if the body is 0 or more,
      # the parse itself is always successful so it is a normal request
      # whether the data of the body is insufficient is not to check here
      # ##
      if likely(bodyStart > 0):
        req.bodyStart = bodyStart 
        return endReq
      else:
        return continueReq

proc contentLengthCheck*(req: mofuwReq): int =
  let cLenHeader = req.getHeader("Content-Length")

  if cLenHeader != "":
    try:
      return parseInt(cLenHeader)
    except:
      return -1
  else:
    # ##
    # not found "Content-Length
    # ##
    return -2

macro recvCheck*(rcv: var int, res: mofuwRes, buf: pointer, bufLen: int): untyped =
  quote do:
    let fut = mofuwRecvInto(`res`, `buf`, `bufLen`)
    yield fut
    `rcv` = fut.read
    if `rcv` == 0: `res`.mofuwClose(); return

proc saveBuffer*(r: int, req: mofuwReq, buf: pointer) =
  let ol = req.buf.len
  req.buf.setLen(ol+r)
  copyMem(addr req.buf[ol], buf, r)

macro mofuwCallback*(req: mofuwReq, res: mofuwRes): untyped =
  quote do:
    # TODO: timeout.
    let fut = getCallback()(`req`, `res`)
    yield fut
    if fut.failed:
      # TODO: error check.
      let fut = `res`.badGateway()
      fut.callback = proc() =
        `res`.mofuwClose()
      return

proc notFound*(res: mofuwRes) {.async.} =
  await mofuwSend(res, notFound())

proc badRequest*(res: mofuwRes) {.async.} =
  await mofuwSend(res, badRequest())

proc bodyTooLarge*(res: mofuwRes) {.async.} =
  await mofuwSend(res, bodyTooLarge())

proc badGateway*(res: mofuwRes) {.async.} =
  await mofuwSend(res, makeResp(
    HTTP502,
    "text/plain",
    "502 Bad Gateway"))

proc fileResp(res: mofuwRes, filePath, file: string) {.async.}=
  let (_, _, ext) = splitFile(filePath)

  if ext == "":
    await res.mofuwSend(makeResp(
      HTTP200,
      "text/plain",
      file
    ))
  else:
    let mime = newMimetypes()

    await res.mofuwSend(makeResp(
      HTTP200,
      mime.getMimetype(ext[1 .. ^1], default = "application/octet-stream"),
      file
    ))

proc staticServe*(req: mofuwReq, res: mofuwRes, rootPath: string): Future[bool] {.async.} =
  var
    state = 0
    reqPath = getPath(req)
    filePath = rootPath

  for k, v in reqPath:
    if v == '.':
      if reqPath[k+1] == '.':
        await res.mofuwSend(badRequest())
        return true

  if filePath[^1] != '/':
    filePath.add("/")
    filePath.add(reqPath[state .. ^1])
  else:
    filePath.add(reqPath[state .. ^1])

  if filePath[^1] != '/':
    if existsDir(filePath):
      # Since the Host header should always exist,
      # Nil check is not done here
      let host = getHeader(req, "Host")

      reqPath.add("/")

      await res.mofuwSend(redirectTo(
        "http://" / host / reqPath
      ))

      return true
    if fileExists(filePath):
      let
        f = openAsync(filePath, fmRead)
        file = await f.readAll()
      close(f)
      await res.fileResp(filePath, file)
      return true
    else:
      return false
  else:
    filePath.add("index.html")
    if fileExists(filePath):
      let
        f = openAsync(filePath, fmRead)
        file = await f.readAll()
      close(f)
      await res.fileResp(filePath, file)
      return true
    else:
      return false