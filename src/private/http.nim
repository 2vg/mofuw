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
proc doubleCRLFCheck*(ctx: MofuwCtx): ReqState =
  # ##
  # parse request
  # ##
  let bodyStart = ctx.mhr.mpParseRequest(addr ctx.buf[0], ctx.buf.len)

  # ##
  # found HTTP Method, return
  # not found, 0 length string
  # ##
  let hMethod =
    if not ctx.mhr.httpMethod.isNil: ctx.getMethod
    else: ""

  if likely(hMethod == "GET" or hMethod == "HEAD"):
    # ##
    # check \r\l\r\l
    # ##
    if ctx.buf[^1] == '\l' and ctx.buf[^2] == '\r' and
       ctx.buf[^3] == '\l' and ctx.buf[^4] == '\r':
      # ##
      # if not bodyStart > 0, request is invalid.
      # ##
      if likely(bodyStart != -1):
        ctx.bodyStart = bodyStart
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
      for i, ch in ctx.buf:
        if ch == '\r':
          if ctx.buf.lenCheck(i+1) == '\l' and
             ctx.buf.lenCheck(i+2) == '\r' and
             ctx.buf.lenCheck(i+3) == '\l':
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
    # ctx.buf.len - bodyStart = request body size
    # ##
    if unlikely(ctx.buf.len - bodyStart > getMaxBodySize()):
      return bodyLarge
    else:
      # ##
      # if the body is 0 or more,
      # the parse itself is always successful so it is a normal request
      # whether the data of the body is insufficient is not to check here
      # ##
      if likely(bodyStart > 0):
        ctx.bodyStart = bodyStart 
        return endReq
      else:
        return continueReq

proc contentLengthCheck*(ctx: MofuwCtx): int =
  let cLenHeader = ctx.getHeader("Content-Length")

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

proc saveBuffer*(r: int, ctx: MofuwCtx, buf: pointer) =
  let ol = ctx.buf.len
  ctx.buf.setLen(ol+r)
  copyMem(addr ctx.buf[ol], buf, r)

template mofuwCallback*(ctx: MofuwCtx): untyped =
  block:
    # TODO: timeout.
    let fut = getCallback()(ctx)
    yield fut
    if fut.failed:
      # TODO: error check.
      let fut = ctx.badGateway()
      fut.callback = proc() =
        ctx.mofuwClose()
      return

proc notFound*(ctx: MofuwCtx) {.async.} =
  await mofuwSend(ctx, notFound())

proc badRequest*(ctx: MofuwCtx) {.async.} =
  await mofuwSend(ctx, badRequest())

proc bodyTooLarge*(ctx: MofuwCtx) {.async.} =
  await mofuwSend(ctx, bodyTooLarge())

proc badGateway*(ctx: MofuwCtx) {.async.} =
  await mofuwSend(ctx, makeResp(
    HTTP502,
    "text/plain",
    "502 Bad Gateway"))

proc fileResp(ctx: MofuwCtx, filePath, file: string) {.async.}=
  let (_, _, ext) = splitFile(filePath)

  if ext == "":
    await ctx.mofuwSend(makeResp(
      HTTP200,
      "text/plain",
      file
    ))
  else:
    let mime = newMimetypes()

    await ctx.mofuwSend(makeResp(
      HTTP200,
      mime.getMimetype(ext[1 .. ^1], default = "application/octet-stream"),
      file
    ))

proc staticServe*(ctx: MofuwCtx, rootPath: string): Future[bool] {.async.} =
  var
    state = 0
    reqPath = getPath(ctx)
    filePath = rootPath

  for k, v in reqPath:
    if v == '.':
      if reqPath[k+1] == '.':
        await ctx.mofuwSend(badRequest())
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
      let host = getHeader(ctx, "Host")

      reqPath.add("/")

      await ctx.mofuwSend(redirectTo(
        "http://" / host / reqPath
      ))

      return true
    if fileExists(filePath):
      let
        f = openAsync(filePath, fmRead)
        file = await f.readAll()
      close(f)
      await ctx.fileResp(filePath, file)
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
      await ctx.fileResp(filePath, file)
      return true
    else:
      return false