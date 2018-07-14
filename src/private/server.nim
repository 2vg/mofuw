import core, handler
import mofuhttputils
import strtabs, openssl, threadpool, asyncdispatch

when defined(vhost): import critbits

proc updateTime(fd: AsyncFD): bool =
  updateServerTime()
  return false

proc serverLoop(server: AsyncFD) {.async.} =
  var cantAccept = false
  while true:
    if unlikely cantAccept:
      await sleepAsync(10)
      cantAccept = false

    try:
      let data = await acceptAddr(server)
      let (address, client) = data
      #client.SocketHandle.setBlocking(false)
      # handler error check.
      asyncCheck handler(client, address)
    except:
      # TODO async sleep.
      # await sleepAsync(10)
      cantAccept = true

when defined(vhost):
  proc runServerVhost(port, maxBodySize: int;
               cb: Callback, tbl: CritBitTree[Callback]) {.thread.} =

    let server = newServerSocket(port).AsyncFD
    setMaxBodySize(maxBodySize)
    register(server)
    updateServerTime()
    addTimer(1000, false, updateTime)
    setCallback(cb)
    setCallBackTable(tbl)

    waitFor serverLoop(server)
else:
  proc runServer(port, maxBodySize: int;
               cb: Callback) {.thread.} =

    let server = newServerSocket(port).AsyncFD
    setMaxBodySize(maxBodySize)
    register(server)
    updateServerTime()
    addTimer(1000, false, updateTime)
    setCallback(cb)

    waitFor serverLoop(server)

proc mofuwRun*(cb: Callback,
               port: int = 8080,
               maxBodySize: int = defaultMaxBodySize) =

  if cb == nil: raise newException(Exception, "callback is nil.")

  #if isDebug.bool:
  #  errorLogFile = openAsync("error.log")
  #  accessLogFile = openAsync("access.log")

  for i in 0 ..< countCPUs():
    when defined(vhost):
      spawn runServerVhost(port, maxBodySize, cb, getCallBackTable())
    else:
      spawn runServer(port, maxBodySize, cb)
  sync()

proc mofuwRun*(port: int = 8080,
               maxBodySize: int = defaultMaxBodySize) =

  if getCallback() == nil: raise newException(Exception, "callback is nil.")
  mofuwRun(getCallback(), port, maxBodySize)

when defined ssl:
  proc mofuwRunWithSSL*(cb: Callback,
                        port: int = 4443,
                        maxBodySize: int = defaultMaxBodySize,
                        sslVerify = true) =
    if sslVerify: mofuwSSLInit(CVerifyPeer)
    else: mofuwSSLInit(CVerifyNone)
    mofuwRun(cb, port, maxBodySize)

  proc mofuwRunWithSSL*(port: int = 4443,
                        maxBodySize: int = defaultMaxBodySize,
                        sslVerify = true) =
    mofuwRunWithSSL(getCallback(), port, maxBodySize, sslVerify)