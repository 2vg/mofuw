import ctx, io
import mofuparser, mofuhttputils
<<<<<<< HEAD
import os, macros, strutils, mimetypes, asyncdispatch, asyncfile
import ../mofuw/middleware/etags
=======
import os, macros, strtabs, strutils, parseutils,
       mimetypes, asyncdispatch, asyncfile

from httpcore import HttpHeaders

proc getMethod*(ctx: MofuwCtx): string {.inline.} =
  result = getMethod(ctx.mhr)

proc getPath*(ctx: MofuwCtx): string {.inline.} =
  result = getPath(ctx.mhr)

proc getCookie*(ctx: MofuwCtx): string {.inline.} =
  result = getHeader(ctx.mhr, "Cookie")

proc getHeader*(ctx: MofuwCtx, name: string): string {.inline.} =
  result = getHeader(ctx.mhr, name)

proc toHttpHeaders*(ctx: MofuwCtx): HttpHeaders {.inline.} =
  result = ctx.mhr.toHttpHeaders()

proc setParam*(ctx: MofuwCtx, params: StringTableRef) {.inline.} =
  ctx.uriParams = params

proc setQuery*(ctx: MofuwCtx, query: StringTableRef) {.inline.} =
  ctx.uriQuerys = query

proc params*(ctx: MofuwCtx, key: string): string =
  if ctx.uriParams.isNil: return nil
  ctx.uriParams.getOrDefault(key)

proc query*(ctx: MofuwCtx, key: string): string =
  if ctx.uriQuerys.isNil: return nil
  ctx.uriQuerys.getOrDefault(key)

proc bodyParse*(query: string):StringTableRef {.inline.} =
  result = {:}.newStringTable
  var i = 0
  while i < query.len()-1:
    var key = ""
    var val = ""
    i += query.parseUntil(key, '=', i)
    if query[i] != '=':
      raise newException(ValueError, "Expected '=' at " & $i &
                         " but got: " & $query[i])
    inc(i) # Skip =
    i += query.parseUntil(val, '&', i)
    inc(i) # Skip &
    result[key] = val

# ##
# get body
# req.body -> all body
# req.body("user") -> get body query "user"
# ##
proc body*(ctx: MofuwCtx, key: string = nil): string =
  if key.isNil: return $ctx.buf[ctx.bodyStart ..< ctx.bufLen]
  if ctx.bodyParams.isNil: ctx.bodyParams = ctx.body.bodyParse
  ctx.bodyParams.getOrDefault(key)

proc notFound*(ctx: MofuwCtx) {.async.} =
  await mofuwSend(ctx, notFound())
  await ctx.mofuwWrite()

proc badRequest*(ctx: MofuwCtx) {.async.} =
  await mofuwSend(ctx, badRequest())
  await ctx.mofuwWrite()

proc bodyTooLarge*(ctx: MofuwCtx) {.async.} =
  await mofuwSend(ctx, bodyTooLarge())
  await ctx.mofuwWrite()

proc badGateway*(ctx: MofuwCtx) {.async.} =
  await mofuwSend(ctx, makeResp(
    HTTP502,
    "text/plain",
    "502 Bad Gateway"))
  await ctx.mofuwWrite()
>>>>>>> upstream/master

type
  ReqState* = enum
    badReq = -3,
    bodyLarge,
    continueReq,
    endReq

proc doubleCRLFCheck*(ctx: MofuwCtx): ReqState =
  # ##
  # parse request
  # ##
  let bodyStart = ctx.mhr.mpParseRequest(addr ctx.buf[ctx.currentBufPos], ctx.bufLen - 1)

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
    let last = ctx.bufLen
    if ctx.buf[last-1] == '\l' and ctx.buf[last-2] == '\r' and
       ctx.buf[last-3] == '\l' and ctx.buf[last-4] == '\r':
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
            # but it is an illegal request because the method is empty
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
    if unlikely(ctx.bufLen - bodyStart > ctx.maxBodySize):
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

proc haveBodyHandler*(ctx: MofuwCtx, handler: MofuwHandler): Future[bool] {.async.} =
  let hasContentLength = ctx.contentLengthCheck()
  if hasContentLength != -2:
    if hasContentLength != -1:
      while not(ctx.bufLen - ctx.bodyStart >= hasContentLength):
        let rcv = await ctx.mofuwRead()
        if rcv == 0: ctx.mofuwClose(); return false
      await handler(ctx)
      asyncCheck ctx.mofuwWrite()
      ctx.bufLen = 0
      ctx.currentBufPos = 0
      return true
    else:
      # TODO: Content-Length error.
      discard
  elif ctx.getHeader("Transfer-Encoding") == "chunked":
    ctx.mc = MPchunk()
    # Parsing chunks already in the buffer
    var chunkBuf = ctx.body[0]
    var chunkLen = ctx.bufLen - ctx.bodyStart
    var parseRes = ctx.mc.mpParseChunk(addr chunkBuf, chunkLen)

    if parseRes == -1:
      await ctx.badRequest()
      ctx.mofuwClose()
      return false

    ctx.bufLen = ctx.bodyStart + chunkLen

    await handler(ctx)
    await ctx.mofuwWrite()

    if parseRes == -2:
      while true:
        chunkBuf = ctx.body[ctx.bufLen]
        chunkLen = await ctx.mofuwRead()
        let pRes = ctx.mc.mpParseChunk(addr chunkBuf, chunkLen)
        case pRes
        of -2:
          ctx.bufLen = ctx.bodyStart + chunkLen
          await handler(ctx)
          await ctx.mofuwWrite()
        of -1:
          await ctx.badRequest()
          ctx.mofuwClose()
          return false
        else:
          if parseRes != 2:
            discard await ctx.mofuwRead()
          await handler(ctx)
          await ctx.mofuwWrite()
          break

    ctx.bufLen = 0
    ctx.currentBufPos = 0
    return true
  else:
    await ctx.badRequest()
    ctx.mofuwClose()
    return false

proc fileResp(ctx: MofuwCtx, filePath, file: string) {.async.}=
  let (_, _, ext) = splitFile(filePath)

  if ext == "":
    await ctx.mofuwSend(makeResp(
      HTTP200,
      "text/plain" & (if etagEnabled : "\c\lEtag:" & filePath.getEtag else :"" ),
      file
    ))
  else:
    let mime = newMimetypes()

    await ctx.mofuwSend(makeResp(
      HTTP200,
      mime.getMimetype(ext[1 .. ^1], default = "application/octet-stream") & (if etagEnabled : "\c\lEtag:" & filePath.getEtag else :"" ),
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

      # etag
      if etagEnabled :
        let etag = getHeader(req, "If-None-Match")
        if not isModifiedEtagWithUpdate(filePath, etag) :
          await mofuwSend(res, makeResp(HTTP304,"","") )
          return true

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

      # etag
      if etagEnabled :
        let etag = getHeader(req, "If-None-Match")
        if not isModifiedEtagWithUpdate(filePath, etag) :
          await mofuwSend(res, makeResp(HTTP304,"","") )
          return true

      let
        f = openAsync(filePath, fmRead)
        file = await f.readAll()
      close(f)
      await ctx.fileResp(filePath, file)
      return true
    else:
      return false