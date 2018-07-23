import ctx, ctxpool, handler, sysutils
import mofuhttputils
import net, critbits, nativesockets, asyncdispatch, threadpool

when defined(windows):
  from winlean import TCP_NODELAY
else:
  from posix import TCP_NODELAY

proc registerCallback*(ctx: ServeCtx, serverName: string, cb: MofuwHandler) =
  ctx.vhostTbl[serverName] = cb
  if not ctx.vhostTbl.hasKey(""): ctx.vhostTbl[""] = cb

proc setCallBackTable*(servectx: ServeCtx, ctx: MofuwCtx) =
  ctx.vhostTbl = servectx.vhostTbl

proc getCallBackTable*(ctx: MofuwCtx): VhostTable =
  ctx.vhostTbl

proc updateTime(fd: AsyncFD): bool =
  updateServerTime()
  return false

proc newServerSocket*(port: int): SocketHandle =
  let server = newSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.setSockOpt(OptReusePort, true)
  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)
  server.getFd.setBlocking(false)
  server.bindAddr(Port(port))
  server.listen()#defaultBacklog().cint)
  return server.getFd()

proc initCtx*(servectx: ServeCtx, ctx: MofuwCtx, fd: AsyncFD, ip: string): MofuwCtx =
  ctx.fd = fd
  ctx.ip = ip
  ctx.bufLen = 0
  ctx.respLen = 0
  ctx.currentBufPos = 0
  if unlikely ctx.buf.len != servectx.readBufferSize: ctx.buf.setLen(servectx.readBufferSize)
  if unlikely ctx.resp.len != servectx.writeBufferSize: ctx.buf.setLen(servectx.writeBufferSize)
  ctx

proc mofuwServe*(ctx: ServeCtx, isSSL: bool) {.async.} =
  initCtxPool(ctx.readBufferSize, ctx.writeBufferSize, ctx.poolsize)

  let server = ctx.port.newServerSocket().AsyncFD
  register(server)
  setServerName(ctx.serverName)
  updateServerTime()
  addTimer(1000, false, updateTime)

  var cantaccept = false

  while true:
    if unlikely cantaccept:
      await sleepAsync(10)
      cantaccept = true

    try:
      let data = await acceptAddr(server)
      let mCtx = ctx.initCtx(getCtx(ctx.readBufferSize, ctx.writeBuffersize), data[1], data[0])
      setCallBackTable(ctx, mCtx)
      mCtx.maxBodySize = ctx.maxBodySize
      when defined ssl:
        if unlikely isSSL:
          mCtx.isSSL = true
          ctx.toSSLSocket(mCtx)
      asyncCheck handler(ctx, mCtx)
    except:
      # TODO async sleep.
      # await sleepAsync(10)
      cantAccept = true

proc runServer*(ctx: ServeCtx, isSSL = false) {.thread.} =
  if isSSl:
    waitFor ctx.mofuwServe(true)
  else:
    waitFor ctx.mofuwServe(false)

proc serve*(ctx: ServeCtx) =
  if ctx.handler.isNil:
    raise newException(Exception, "Callback is nil. please set callback.")

  for _ in 0 ..< countCPUs():
    spawn ctx.runServer(ctx.isSSL)

  when not defined noSync:
    sync()