import nativesockets

from osproc import countProcessors

import lib/nimuv
import lib/mofuparser
import lib/httputils

const
  kByte* = 1024
  mByte* = 1024 * kByte

  maxBodySize = 1 * mByte

type
  mofuwReq* = object
    handle: ptr uv_handle_t
    reqLine: HttpReq
    reqHeader*: array[48, headers]
    reqHeaderAddr: ptr mofuwReq.reqHeader
    reqBody*: cstring
    reqBodyLen*: int

  mofuwRes* = object
    handle: ptr uv_handle_t
    fd: cint
    res: ptr uv_write_t
    body: uv_buf_t

  Callback* = proc(req: ptr mofuwReq, res: ptr mofuwRes)

var callback* {.threadvar.}: Callback

proc getMethod*(req: ptr mofuwReq): string {.inline.} =
  result = ($(req.reqLine.method))[0 .. req.reqLine.methodLen]

proc getPath*(req: ptr mofuwReq): string {.inline.} =
  result = ($(req.reqLine.path))[0 .. req.reqLine.pathLen]

proc getReqBody*(req: ptr mofuwReq): string {.inline.} =
  result = $req.reqBody

proc after_close(handle: ptr uv_handle_t) {.cdecl.} =
  return

proc free_response(req: ptr uv_write_t, status: cint) {.cdecl.} =
  dealloc(req)

proc buf_alloc(handle: ptr uv_handle_t, size: csize, buf: ptr uv_buf_t) {.cdecl.} =
  buf.base = cast[ptr char](alloc0(4096))
  buf.len = 4096

proc mofuw_send*(res: ptr mofuwRes, body: cstring) {.inline.}=
  res.body.base = cast[ptr char](body)
  res.body.len = body.len

  if not uv_write(res.res, cast[ptr uv_stream_t](res.handle), res.body.addr, 1, free_response) == 0:
    dealloc(res.res)
    return

proc notFound*(res: ptr mofuwRes) =
  mofuw_send(res, notFound())

proc read_cb(stream: ptr uv_stream_t, nread: cssize, buf: ptr uv_buf_t) {.cdecl.} =
  #echo repr cast[cstring](buf.base)

  if nread == 0: return

  if nread == -4095:
    dealloc(buf.base.pointer)
    uv_close(cast[ptr uv_handle_t](stream), after_close)
    return
  elif nread < 0:
    dealloc(buf.base.pointer)
    uv_close(cast[ptr uv_handle_t](stream), after_close)
    return

  var
    req = mofuwReq()
    request = addr(req)
    res = mofuwRes()
    response = addr(res)

  request.reqHeaderAddr = request.reqHeader.addr

  response.handle = cast[ptr uv_handle_t](stream)

  response.res = cast[ptr uv_write_t](alloc(sizeof(uv_write_t)))

  let r = mp_req(buf.base, request.reqLine, request.reqHeaderAddr)

  if r <= 0:
    notFound(response)
    dealloc(stream)
    dealloc(buf.base)
    uv_close(cast[ptr uv_handle_t](stream), after_close)
    return

  request.reqBody = cast[cstring](cast[int](buf.base) + r)

  #if request.reqBodyLen > maxBodySize:
  #  mofuw_send(response, bodyTooLarge())
  #  dealloc(buf.base)
  #  return

  callback(request, response)

  dealloc(buf.base)

proc accept_cb(server: ptr uv_stream_t, status: cint) {.cdecl.} =
  if not status == 0:
    echo "error: ", uv_err_name(status), uv_strerror(status), "\n"

  var client = cast[ptr uv_stream_t](alloc(sizeof(uv_tcp_t)))

  if not uv_tcp_init(server.loop, cast[ptr uv_tcp_t](client)) == 0:
    return

  if not uv_accept(server, client) == 0:
    return

  if not uv_read_start(client, buf_alloc, read_cb) == 0:
    return

proc updateServerTime(handle: ptr uv_timer_t) {.cdecl.}=
  httputils.updateServerTime()

proc mofuw_init*(t: tuple[port: int, backlog: int, cb: Callback]) =
  var
    server: ptr uv_tcp_t = cast[ptr uv_tcp_t](alloc(sizeof(uv_tcp_t)))
    loop: ptr uv_loop_t = cast[ptr uv_loop_t](alloc(sizeof(uv_loop_t)))
    timer: ptr uv_timer_t = cast[ptr uv_timer_t](alloc(sizeof(uv_timer_t)))
    sockaddr: SockAddrIn
    fd: uv_os_fd_t

  callback = t.cb

  discard uv_loop_init(loop)

  discard uv_ip4_addr("0.0.0.0".cstring, t.port.cint, addr(sockaddr))

  discard uv_tcp_init_ex(loop, server, AF_INET.cuint)

  discard uv_tcp_nodelay(server, 1)

  discard uv_tcp_simultaneous_accepts(server, 1)

  discard uv_fileno(cast[ptr uv_handle_t](server), addr(fd))

  fd.SocketHandle.setSockOptInt(cint(SOL_SOCKET), SO_REUSEPORT, 1)

  discard uv_tcp_bind(server, cast[ptr SockAddr](addr(sockaddr)), 0)

  discard uv_listen(cast[ptr uv_stream_t](server), t.backlog.cint, accept_cb)

  discard uv_timer_init(loop, timer)

  discard uv_timer_start(timer, updateServerTime, 0.uint64, 1000.0.uint64)

  httputils.updateServerTime()

  discard uv_run(loop, UV_RUN_DEFAULT)

proc mofuwRUN*(port: int = 8080, backlog: int = 128) =
  var th: Thread[tuple[port: int, backlog: int, cb: Callback]]

  if callback == nil:
    raise newException(Exception, "callback is nil.")

  for i in 0 ..< countProcessors():
    createThread[tuple[port: int, backlog: int, cb: Callback]](
      th, mofuw_init, (port, backlog, callback)
    )

  joinThread(th)
