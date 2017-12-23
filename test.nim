import net, nativesockets, nimev, mofuparser

# accept with fd set nonblocking
proc accept4(a1: cint, a2: ptr SockAddr, a3: ptr Socklen, flags: cint): cint
  {.importc, header: "<sys/socket.h>".}

var
  loop = ev_default_loop(0)

  #[
  async_read = proc(fd: cint) =
    let r = w.fd.SocketHandle.recv(addr(incoming), incoming.len, 0).cint

  read_cb: ev_async_cb = proc(loop: ptr ev_loop_t, w: ptr ev_async, revents: cint): void {.cdecl.} =
    read_watcher: ev_async]#

  # import TCP_NODELAY for disable Nagle algorithm
  TCP_NODELAY {.importc: "TCP_NODELAY", header: "<netinet/tcp.h>".}: cint

  # for accept4
  SOCK_NONBLOCK* {.importc, header: "<sys/socket.h>".}: cint

  # for accept4
  SOCK_CLOEXEC* {.importc, header: "<sys/socket.h>".}: cint

  # test response data
  body = "HTTP/1.1 200 OK" & "\r\L" &
         "Connection: keep-alive" & "\r\L" &
         "Content-Length: 11"  & "\r\L" &
         "Content-Type: text/plain; charset=utf-8" & "\r\L" & "\r\L" &
         "Hello World"

  htreq: HttpReq
  hd : array[64, headers]
  hdaddr = hd.addr

  client_cb: ev_io_cb = proc(loop: ptr ev_loop_t, w: ptr ev_io, revents: cint): void {.cdecl.} =
    var incoming: array[1024, char]
    let r = w.fd.SocketHandle.recv(addr(incoming), incoming.len, 0).cint

    if r < 0:
      echo "error"
    elif r == 0:
      w.fd.SocketHandle.close()
      ev_io_stop(loop, w)
      dealloc(w)
    else:
      discard mp_req(incoming[0].addr, htreq, hdaddr)
      discard w.fd.SocketHandle.send(addr(body[0]), body.len, 0)

  server_cb: ev_io_cb = proc(loop: ptr ev_loop_t, w: ptr ev_io, revents: cint): void {.cdecl.} =
    var
      sockAddress: SockaddrIn
      addrLen = sockAddress.sizeof.SockLen
      client_watcher = cast[ptr ev_io](alloc(sizeof(ev_io)))

    var client = w.fd.accept4(cast[ptr SockAddr](addr(sockAddress)), addr(addrLen), SOCK_NONBLOCK or SOCK_CLOEXEC)

    w.fd.SocketHandle.setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)

    ev_io_init(client_watcher, client_cb, client, EV_READ)
    ev_io_start(loop, client_watcher)

# create and setupserver listen socket
proc newServerSocket(port: int = 8080, backlog: int = SOMAXCONN): cint =
  let server = newSocket()

  # reuse address
  server.setSockOpt(OptReuseAddr, true)       
  # reuse port
  server.setSockOpt(OptReusePort, true)
  # set nonblocking
  server.getFd.setBlocking(false)

  # bind port
  server.bindAddr(Port(port))
  # listen binding port and set maxbacklog
  server.listen(backlog.cint)

  return server.getFd().cint

var
  watcher: ev_io
  server = newServerSocket()

ev_io_init(watcher.addr, server_cb, server, EV_READ)
ev_io_start(loop, watcher.addr)

#setMinPoolSize(countProcessors())
#setMaxPoolSize(countProcessors())

ev_loop(loop, 0)

server.SocketHandle.close()