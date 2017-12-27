import net, nativesockets, osproc, os, threadpool, lib/nimev, lib/mofuparser

type
  worker_t = tuple[
    loop: ptr ev_loop_t,
    w: ptr ev_async
  ]

  handle_t = object
    fd: cint

  worker_obj = object
    io: ev_io
    w_id: int
    async: seq[ptr ev_async]
    arr: seq[ptr ev_loop_t]


var
  # import TCP_NODELAY for disable Nagle algorithm
  TCP_NODELAY {.importc: "TCP_NODELAY", header: "<netinet/tcp.h>".}: cint

  # for accept4
  SOCK_NONBLOCK* {.importc, header: "<sys/socket.h>".}: cint

  # for accept4
  SOCK_CLOEXEC* {.importc, header: "<sys/socket.h>".}: cint

  # test response data
  body {.threadvar.}: string

  htreq: HttpReq
  hd : array[64, headers]
  hdaddr = hd.addr

body =
  "HTTP/1.1 200 OK" & "\r\L" &
  "Connection: keep-alive" & "\r\L" &
  "Content-Length: 11" & "\r\L" &
  "Content-Type: text/html; charset=utf-8" & "\r\L" & "\r\L" &
  "Hello World"

# accept with fd set nonblocking
proc accept4(a1: cint, a2: ptr SockAddr, a3: ptr Socklen, flags: cint): cint
  {.importc, header: "<sys/socket.h>".}

proc newServerSocket(port: int = 8080, backlog: int = SOMAXCONN): cint =
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

proc ev_io_cb(loop: ptr ev_loop_t, w: ptr ev_io, revents: cint) {.cdecl.} =
  var
    sockAddress: SockaddrIn
    addrLen = sockAddress.sizeof.SockLen
    worker: ptr worker_obj = cast[ptr worker_obj](w)
    handle: ptr handle_t = cast[ptr handle_t](handle_t.new())

  handle.fd = w.fd.accept4(cast[ptr SockAddr](addr(sockAddress)), addr(addrLen), SOCK_NONBLOCK or SOCK_CLOEXEC)

  worker.async[worker.w_id].data = handle
  ev_async_send(worker.arr[worker.w_id], worker.async[worker.w_id])

  if handle.fd < 0:
    echo "error accept: " & $(osLastError()) & ": " & $handle.fd

  if worker.w_id == countProcessors() - 1:
    worker.w_id = 0
  else:
    worker.w_id.inc(1)

proc ev_io_cb_2(loop: ptr ev_loop_t, w: ptr ev_io, revents: cint): void {.cdecl.} =
  var
    incoming: array[1024, char]
    testbody =
      "HTTP/1.1 200 OK" & "\r\L" &
      "Connection: keep-alive" & "\r\L" &
      "Content-Length: 11" & "\r\L" &
      "Content-Type: text/html; charset=utf-8" & "\r\L" & "\r\L" &
      "Hello World"

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
    discard mp_req(incoming[0].addr, htreq, hdaddr)
    discard w.fd.SocketHandle.send(addr(testbody[0]), testbody.len, 0)

proc ev_async_cb(loop: ptr ev_loop_t, w: ptr ev_async, revents: cint): void {.cdecl.} =
  var
    client_watcher: ptr ev_io = cast[ptr ev_io](alloc(sizeof(ev_io)))

  ev_io_init(client_watcher, ev_io_cb_2, cast[ptr handle_t](w.data).fd, EV_READ)
  ev_io_start(loop, client_watcher)

  #cast[SocketHandle](w.data).send(addr(body[0]), body.len, 0)

proc ev_timer_cb(loop: ptr ev_loop_t, w: ptr ev_timer, revents: cint): void {.cdecl.} =
  ev_timer_again(loop, w)

proc worker_loop(wl: worker_t) =
  var
    timer_watcher = cast[ptr ev_timer](ev_timer.new())

  ev_async_init(wl.w, ev_async_cb)
  ev_async_start(wl.loop, wl.w)
  
  ev_timer_init(timer_watcher, ev_timer_cb, 10, 0)
  timer_watcher.repeat = 60
  ev_timer_again(wl.loop, timer_watcher)

  discard ev_run(wl.loop, 0)

proc accept_loop(loop: ptr ev_loop_t, worker_arr: seq[ptr ev_loop_t]) =
  var
    watcher: ptr worker_obj = cast[ptr worker_obj](worker_obj.new())
    server = newServerSocket()
    worker_threads = newSeq[Thread[worker_t]](countProcessors())

  watcher.async = @[]

  watcher.w_id = 0

  for i in 0 ..< worker_arr.len:
    watcher.async.add(cast[ptr ev_async](ev_async.new()))
    var worker: worker_t = (worker_arr[i], watcher.async[i])
    createThread[worker_t](worker_threads[i], worker_loop, worker)

  watcher.arr = worker_arr

  ev_io_init(watcher.io.addr, ev_io_cb, server, EV_READ)
  ev_io_start(loop, watcher.io.addr)

  echo "main"
  discard ev_run(loop, 0)
  echo "server close"
  server.SocketHandle.close()

var
  main_loop: ptr ev_loop_t = ev_default_loop(0)
  th_loop: seq[ptr ev_loop_t] = @[]

for i in 0 ..< countProcessors():
  th_loop.add(ev_loop_new(1))

accept_loop(main_loop, th_loop)

#createThread[server_t](server_threads, accept_loop, server_s)

#setMinPoolSize(countProcessors())
#setMaxPoolSize(countProcessors())
#joinThreads(server_threads)