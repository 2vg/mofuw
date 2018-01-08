import selectors, net, nativesockets, os, streams, threadpool

import lib/httputils
import lib/mofuparser

from osproc import countProcessors
from posix import EAGAIN, EWOULDBLOCK

type
  fdType = enum
    SERVER,
    CLIENT,
    ASYNC

  Data = object
    `type`: fdType
    buf: string
    queue: int
    sent: int
    fd: int
    results: pointer
    cb: proc(fd: int, res: pointer)

var
  # import TCP_NODELAY for disable Nagle algorithm
  TCP_NODELAY {.importc: "TCP_NODELAY", header: "<netinet/tcp.h>".}: cint

  # for accept4
  SOCK_NONBLOCK* {.importc, header: "<sys/socket.h>".}: cint
  
  # for accept4
  SOCK_CLOEXEC* {.importc, header: "<sys/socket.h>".}: cint

  selector {.threadvar.}: Selector[Data]

proc newGlobalSelector*(): Selector[Data] =
  result = newSelector[Data]()

proc setGlobalSelector*(sel: Selector) =
  selector = sel

proc getGlobalSelector*(): Selector[Data] =
  if selector.isNil:
    setGlobalSelector(newGlobalSelector())

  result = selector

proc accept4(a1: cint, a2: ptr SockAddr, a3: ptr Socklen, flags: cint): cint
  {.importc, header: "<sys/socket.h>".}

proc newData(typ: fd_type, fd: int = 0, res: pointer = nil, cb: proc(fd: int, res: pointer) = nil): Data =
  Data(
    type: typ,
    buf: "",
    queue: 0,
    sent: 0,
    fd: fd,
    results: res,
    cb: cb
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

proc AsyncFileRead*(selector: Selector, path: string, fd: int, cb: proc(fd: int, res: pointer)): void =
  var
    completer = newSelectEvent()
    Fut: cstring

  selector.registerEvent(completer, newData(ASYNC, fd, addr(Fut), cb))
  
  let fs = newFileStream(path, fmRead)
  
  if not isNil(fs):
    Fut =
      makeResp(
        HTTP200,
        "text/plain",
        readAll(fs)
      )

  else:
    Fut = notFound()
  
  fs.close()

  trigger(completer)

proc eventHandler(selector: Selector[Data], 
                  ev: array[64, ReadyKey],
                  cnt: int,) =

  for i in 0 ..< cnt:
    let fd = ev[i].fd
    var data: ptr Data = addr(selector.getData(fd))

    proc getFD(): int =
      result = fd

    proc asyncFile(path: string, cb: proc(fd: int, res: pointer)) =
      spawn AsyncFileRead(getGlobalSelector(), path, getFD(), cb)

    case data.type
    of SERVER:
      var
        sockAddress: Sockaddr_in
        addrLen = SockLen(sizeof(sockAddress))

      let client = accept4(fd.cint, cast[ptr SockAddr](addr(sockAddress)), addr(addrLen), SOCK_NONBLOCK or SOCK_CLOEXEC)

      if client < 0:
        return

      selector.registerHandle(client.SocketHandle, {Event.Read}, newData(CLIENT))

    of CLIENT:
      const size = 256
      var buf: array[size, char]

      while true:
        let r = recv(fd.SocketHandle, addr(buf[0]), size, 0)

        if r == 0:
          selector.unregister(fd)
          close(fd.SocketHandle)
          return

        if r == -1:
          if osLastError().int in {EWOULDBLOCK, EAGAIN}:
            break
          selector.unregister(fd)
          close(fd.SocketHandle)
          return

        data.buf.add(addr(buf[0]))

      #let r = mp_req()

      var body = 
        makeResp(
          HTTP200,
          "text/plain",
          "Hello World"
        )

      proc read_cb(fd: int, res: pointer) =
        discard send(fd.SocketHandle, cast[ptr cstring](res), cast[ptr cstring](res)[].len, 0)

        data.buf.setLen(0)

      #asyncFile("public/index.html", read_cb)

      discard send(fd.SocketHandle, addr(body[0]), body.len, 0)

      data.buf.setLen(0)

    of ASYNC:
      data.cb(data.fd, data.results)

    else:
      discard

proc eventLoop() {.thread.}=
  let
    server = newServerSocket()
    selector = getGlobalSelector()

  selector.registerHandle(server, {Event.Read}, newData(SERVER))

  var ev: array[64, ReadyKey]
  while true:
    let cnt = selector.selectInto(-1, ev)
    eventHandler(selector, ev, cnt)

var threads: Thread[void]

for i in 0 ..< countProcessors():
  createThread(threads, eventLoop)

joinThread(threads)