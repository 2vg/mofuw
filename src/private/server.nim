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
  server.listen(defaultBacklog().cint)
  return server.getFd()

proc initCtx*(ctx: MofuwCtx, fd: AsyncFD, ip: string): MofuwCtx =
  ctx.fd = fd
  ctx.ip = ip
  ctx.bufLen = 0
  ctx.respLen = 0
  ctx.currentBufPos = 0
  ctx

proc mofuwServe*(ctx: ServeCtx, isSSL: bool) {.async.} =
  initCtxPool(ctx.readBufferSize, ctx.writeBufferSize, ctx.poolsize)

  let server = ctx.port.newServerSocket().AsyncFD
  register(server)
  setServerName("mofuw")
  updateServerTime()
  addTimer(1000, false, updateTime)

  var cantaccept = false

  while true:
    if unlikely cantaccept:
      await sleepAsync(10)
      cantaccept = true

    try:
      let (address, client) = await acceptAddr(server)
      let mCtx = getCtx(ctx.readBufferSize, ctx.writeBuffersize).initCtx(client, address)
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
  for _ in 0 ..< countCPUs():
    spawn ctx.runServer(ctx.isSSL)

  when not defined noSync:
    sync()