import
    net,
    coro,
    osproc,
    tables,
    strtabs,
    strutils,
    threadpool,
    nativesockets
  
when defined(windows):
  from winlean import TCP_NODELAY
else:
  from posix import TCP_NODELAY, EAGAIN

from os import osLastError

proc newServerSocket(port: int = 8080, backlog: int = 128): SocketHandle =
  let server = newSocket()

  server.setSockOpt(OptReuseAddr, true)

  server.setSockOpt(OptReusePort, true)

  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)

  server.getFd.setBlocking(false)

  server.bindAddr(Port(port))

  server.listen(backlog.cint)

  return server.getFD()

start(proc()=
  let server = newServerSocket()

  var fd: SocketHandle

  while true:
    fd = accept(server)[0]

    if fd.int < 0:
      suspend()
)

run()