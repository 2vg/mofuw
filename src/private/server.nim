import core, handler
import mofuhttputils
import strtabs, openssl, threadpool, asyncdispatch

proc updateTime(fd: AsyncFD): bool =
  updateServerTime()
  return false

proc mofuwInit(port, mBodySize: int;
               ctx: SslCtx = nil) {.async.} =
  let server = newServerSocket(port).AsyncFD
  setMaxBodySize(mBodySize)
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
      #client.SocketHandle.setBlocking(false)
      # handler error check.
      asyncCheck handler(client, address)
    except:
      # TODO async sleep.
      # await sleepAsync(10)
      cantAccept = true

proc run(port, maxBodySize: int;
         cb: Callback) {.thread.} =

  setCallback(cb)
  waitFor mofuwInit(port, maxBodySize)

proc mofuwRun*(cb: Callback,
               port: int = 8080,
               maxBodySize: int = defaultMaxBodySize) =

  if cb == nil: raise newException(Exception, "callback is nil.")

  #if isDebug.bool:
  #  errorLogFile = openAsync("error.log")
  #  accessLogFile = openAsync("access.log")

  for i in 0 ..< countCPUs(): spawn run(port, maxBodySize, cb)
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