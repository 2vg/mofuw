import selectors, net, nativesockets, os, streams, threadpool, asyncdispatch, future, strutils

import lib/httputils
import lib/mofuparser
import lib/asyncutils

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

  Request = object
    selector: Selector[Data]
    client: SocketHandle

  reqHandle* = proc (req: Request): Future[void] {.gcsafe.}

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

when defined(linux):
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

proc AsyncFileRead*(sev: ptr SelectEvent, fut: ptr cstring, path: string, cb: proc(fd: int, res: pointer)): void =

  if fileExists(path):
    let f = readFile(path)

    fut[] =
      makeResp(
        HTTP200,
        "text/plain",
        f
      )

  else:
    fut[] = notFound()

  echo repr fut

  trigger(sev[])

proc doReq(req: Request): Future[void] =
  var body = makeResp(
    HTTP200,
    "text/plain",
    "Hello World"
  )

  discard req.client.send(addr(body[0]), body.len, 0)

proc reqComp(theFut: Future[void],
             selector: Selector[Data], fd: int) =
  echo "req"
  if theFut.failed:
    raise theFut.error
  else:
    echo "done"

proc eventHandler(selector: Selector[Data], 
                  ev: array[64, ReadyKey],
                  cnt: int,) =

  for i in 0 ..< cnt:
    let fd = ev[i].fd
    var data: ptr Data = addr(selector.getData(fd))

    proc getFD(): int =
      result = fd

    proc asyncFile(path: string, cb: proc(fd: int, res: pointer)) =
      var
        sev: ptr SelectEvent
        Fut: cstring

      sev[] = newSelectEvent()

      selector.registerEvent(sev[], newData(ASYNC, fd, addr(Fut), cb))

      echo repr sev

      spawn AsyncFileRead(sev, addr(Fut), path, cb)

    case data.type
    of SERVER:
      var
        client: SocketHandle
        sockAddress: Sockaddr_in
        addrLen = SockLen(sizeof(sockAddress))

      when defined(linux):
        client = accept4(fd.cint, cast[ptr SockAddr](addr(sockAddress)), addr(addrLen), SOCK_NONBLOCK or SOCK_CLOEXEC).SocketHandle
      else:
        client = accept(fd.SocketHandle, cast[ptr SockAddr](addr(sockAddress)), addr(addrLen))

      if client.cint < 0:
        return

      selector.registerHandle(client, {Event.Read}, newData(CLIENT))

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

      var request = Request(
        selector: selector,
        client: fd.SocketHandle
      )

      var fut = sleepAsync(1000)#doReq(request)
      fut.callback =
        proc()=
          asyncCheck doReq(request)

      #discard send(fd.SocketHandle, addr(body[0]), body.len, 0)

      #data.buf.setLen(0)

    of ASYNC:
      echo "tes"
      poll(0)

    else:
      discard

proc eventLoop() {.thread.}=
  let
    server = newServerSocket()
    selector = getGlobalSelector()
    disp = repr(getGlobalDispatcher())

  selector.registerHandle(server, {Event.Read}, newData(SERVER))

  echo disp.splitLines[0]
  echo getDispatcherFD(disp)

  selector.registerHandle(getDispatcherFD(disp).SocketHandle, {Event.Read}, newData(ASYNC))

  var ev: array[64, ReadyKey]
  while true:
    let cnt = selector.selectInto(-1, ev)
    eventHandler(selector, ev, cnt)

var threads: Thread[void]

for i in 0 ..< countProcessors():
  createThread(threads, eventLoop)

joinThread(threads)