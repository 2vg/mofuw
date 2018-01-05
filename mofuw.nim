import selectors, net, nativesockets, os, httpcore, asyncdispatch

from osproc import countProcessors
from posix import EAGAIN, EWOULDBLOCK

type
  fd_Type = enum
    SERVER,
    CLIENT

  Data = object
    `type`: fd_type
    buf: string
    queue: int
    sent: int

var
  # import TCP_NODELAY for disable Nagle algorithm
  TCP_NODELAY {.importc: "TCP_NODELAY", header: "<netinet/tcp.h>".}: cint

  # for accept4
  SOCK_NONBLOCK* {.importc, header: "<sys/socket.h>".}: cint
  
  # for accept4
  SOCK_CLOEXEC* {.importc, header: "<sys/socket.h>".}: cint

proc accept4(a1: cint, a2: ptr SockAddr, a3: ptr Socklen, flags: cint): cint
  {.importc, header: "<sys/socket.h>".}

proc newData(fd: fd_type): Data =
  Data(
    type: fd,
    buf: "",
    queue: 0,
    sent: 0
  )

proc newServerSocket(port: int = 8080, backlog: int = 128): SocketHandle =
  let server = newSocket()

  # reuse address
  server.setSockOpt(OptReuseAddr, true)

  # reuse port
  server.setSockOpt(OptReusePort, true)

  # disable Nagle
  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)

  # set nonblocking
  server.getFd.setBlocking(false)

  # bind port
  server.bindAddr(Port(port))

  # listen binding port and set maxbacklog
  server.listen(backlog.cint)

  return server.getFd()

proc eventHandler(fd: AsyncFD) {.async.}=
  var body: string =
    "HTTP/1.1 200 OK" & "\r\L" &
    "Connection: keep-alive" & "\r\L" &
    "Content-Length: " & $(11) & "\r\L" &
    "Content-Type: text/plain; charset=utf-8" & "\r\L" & "\r\L" &
    "Hello World"

  while true:
    let r = await recv(fd, 256)

    if r == "":
      closeSocket(fd)
      return
    else:
      await send(fd, addr(body[0]), body.len)

proc eventLoop() {.async, thread.}=
  let server = newServerSocket()

  setGlobalDispatcher(newDispatcher())

  asyncdispatch.register(server.AsyncFD)

  while true:
    let client = await server.AsyncFD.accept()
    asyncCheck eventHandler(client)

proc main() =
  waitFor eventLoop()

var th: Thread[void]

for i in 0 ..< countProcessors():
  createThread(th, main)

joinThread(th)