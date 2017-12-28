import net, nativesockets, osproc, os, lib/nimev, lib/mofuparser, lib/httputils

type
  worker_t = tuple[
    loop: ptr ev_loop_t,
    w: ptr ev_async
  ]

  handle_t* = object
    fd: cint
    io: ptr ev_io
    router: router
    req_line: HttpReq
    req_header: array[64, headers]
    header_addr: ptr handle_t.req_header

  worker_obj = object
    io: ev_io
    w_id: int
    router: router
    async: seq[ptr ev_async]
    arr: seq[ptr ev_loop_t]

  router = object
    GET: seq[router_t]
    POST: seq[router_t]

  router_t = object
    path: string
    cb: proc(handle: ptr handle_t)

var
  ROUTER: router

  # import TCP_NODELAY for disable Nagle algorithm
  TCP_NODELAY {.importc: "TCP_NODELAY", header: "<netinet/tcp.h>".}: cint

  # for accept4
  SOCK_NONBLOCK* {.importc, header: "<sys/socket.h>".}: cint

  # for accept4
  SOCK_CLOEXEC* {.importc, header: "<sys/socket.h>".}: cint

ROUTER.GET = @[]

# accept with fd set nonblocking
proc accept4(a1: cint, a2: ptr SockAddr, a3: ptr Socklen, flags: cint): cint
  {.importc, header: "<sys/socket.h>".}

proc newServerSocket(port: int, backlog: int): cint =
  let server = newSocket()

  # reuse address
  server.setSockOpt(OptReuseAddr, true)       
  # reuse port
  server.setSockOpt(OptReusePort, true)
  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)
  # set nonblocking
  server.getFd.setBlocking(false)

  # bind port
  server.bindAddr(Port(port))
  # listen binding port and set maxbacklog
  server.listen(backlog.cint)

  return server.getFd().cint

proc mofuw_GET*(path: string, cb: proc(handle: ptr handle_t)) =

  var router: router_t

  router.path = path

  router.cb = cb

  ROUTER.GET.add(router)

proc mofuw_send*(handle: ptr handle_t, body: cstring) =
  discard handle.fd.SocketHandle.send(body, body.len, 0)

proc notFound*(handle: ptr handle_t) =
  mofuw_send(handle, "HTTP/1.1 404 Not Found\r\LConnection: Close\r\LContent-Type: text/html\r\LContent-Length: 13\r\L\r\L404 Not Found") 

proc getMethod*(handle: ptr handle_t):string =
  return ($(handle.req_line.method))[0 .. handle.req_line.methodLen]

proc getPath*(handle: ptr handle_t):string =
   return ($(handle.req_line.path))[0 .. handle.req_line.pathLen]

proc accept(loop: ptr ev_loop_t, w: ptr ev_io, revents: cint) {.cdecl.} =
  var
    sockAddress: SockaddrIn
    addrLen = sockAddress.sizeof.SockLen
    worker: ptr worker_obj = cast[ptr worker_obj](w)
    handle: ptr handle_t = cast[ptr handle_t](handle_t.new())

  handle.fd = w.fd.accept4(cast[ptr SockAddr](addr(sockAddress)), addr(addrLen), SOCK_NONBLOCK or SOCK_CLOEXEC)

  handle.router = worker.router

  handle.header_addr = handle.req_header.addr

  worker.async[worker.w_id].data = handle

  ev_async_send(worker.arr[worker.w_id], worker.async[worker.w_id])

  if handle.fd < 0:
    echo "error accept: " & $(osLastError()) & ": " & $handle.fd

  if worker.w_id == countProcessors() - 1:
    worker.w_id = 0
  else:
    worker.w_id.inc(1)

proc handler(loop: ptr ev_loop_t, w: ptr ev_io, revents: cint): void {.cdecl.} =

  var
    incoming: array[1024, char]
  let r = w.fd.SocketHandle.recv(addr(incoming), incoming.len, 0).cint

  if r == 0:
    #echo "close: " & $(osLastError())
    w.fd.SocketHandle.close()
    ev_io_stop(loop, w)
    dealloc(w)
  elif r < 0:
    if osLastError().cint == EAGAIN or osLastError().cint == EWOULDBLOCK:
      #echo "error: " & $(osLastError()) & ": " & $r & $w.fd
      return
    else:
      w.fd.SocketHandle.close()
      ev_io_stop(loop, w)
      dealloc(w)
      #echo "error close: " & $(osLastError()) & ": " & $r & $w.fd
  else:
    #echo "send: " & $w.fd & ": " & $(osLastError())

    let r = mp_req(incoming[0].addr, cast[ptr handle_t](w.data).req_line, cast[ptr handle_t](w.data).header_addr)

    if r <= 0:
      notFound(cast[ptr handle_t](w.data))
      return

    case getMethod(cast[ptr handle_t](w.data))
    of "GET":
      if cast[ptr handle_t](w.data).router.GET.len == 0:
        notFound(cast[ptr handle_t](w.data))
      else:
        for value in cast[ptr handle_t](w.data).router.GET:
          if getPath(cast[ptr handle_t](w.data)) == value.path:
            value.cb(cast[ptr handle_t](w.data))
          else:
            notFound(cast[ptr handle_t](w.data))
    else:
      notFound(cast[ptr handle_t](w.data))
    #discard w.fd.SocketHandle.send(addr(cast[ptr handle_t](w.data).body[0]), cast[ptr handle_t](w.data).body.len, 0)

proc client_set(loop: ptr ev_loop_t, w: ptr ev_async, revents: cint): void {.cdecl.} =
  cast[ptr handle_t](w.data).io = cast[ptr ev_io](alloc(sizeof(ev_io)))
  cast[ptr handle_t](w.data).io.data = w.data

  ev_io_init(cast[ptr handle_t](w.data).io, handler, cast[ptr handle_t](w.data).fd, EV_READ)
  ev_io_start(loop, cast[ptr handle_t](w.data).io)

proc ev_timer_cb(loop: ptr ev_loop_t, w: ptr ev_timer, revents: cint): void {.cdecl.} =
  ev_timer_again(loop, w)

proc worker_loop(wl: worker_t) =
  var
    timer_watcher = cast[ptr ev_timer](ev_timer.new())

  ev_async_init(wl.w, client_set)
  ev_async_start(wl.loop, wl.w)

  ev_timer_init(timer_watcher, ev_timer_cb, 10, 0)
  timer_watcher.repeat = 60
  ev_timer_again(wl.loop, timer_watcher)

  discard ev_run(wl.loop, 0)

proc server_loop(loop: ptr ev_loop_t, worker_arr: seq[ptr ev_loop_t], r: router, port: int = 8080, backlog: int = SOMAXCONN) =
  var
    watcher: ptr worker_obj = cast[ptr worker_obj](worker_obj.new())
    server = newServerSocket(port, backlog)
    worker_threads = newSeq[Thread[worker_t]](countProcessors())

  watcher.async = @[]

  watcher.router = r

  watcher.w_id = 0

  for i in 0 ..< worker_arr.len:
    watcher.async.add(cast[ptr ev_async](ev_async.new()))
    var worker: worker_t = (worker_arr[i], watcher.async[i])
    createThread[worker_t](worker_threads[i], worker_loop, worker)

  watcher.arr = worker_arr

  ev_io_init(watcher.io.addr, accept, server, EV_READ)
  ev_io_start(loop, watcher.io.addr)

  echo "main"
  discard ev_run(loop, 0)
  echo "server close"
  server.SocketHandle.close()

proc mofuw_run*(port: int = 8080, backlog: int = SOMAXCONN) =
  if ROUTER.GET.len == 0 and
     ROUTER.POST.len == 0:
       raise newException(Exception, "nothing router.")
  var
    main_loop: ptr ev_loop_t = ev_default_loop(0)
    th_loop: seq[ptr ev_loop_t] = @[]

  for i in 0 ..< countProcessors():
    th_loop.add(ev_loop_new(1))

  server_loop(main_loop, th_loop, ROUTER, port, backlog)

#createThread[server_t](server_threads, server_loop, server_s)

#setMinPoolSize(countProcessors())
#setMaxPoolSize(countProcessors())
#joinThreads(server_threads)