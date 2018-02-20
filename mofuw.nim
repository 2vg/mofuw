import nativesockets, strtabs

from osproc import countProcessors
from os import osLastError

import lib/nimuv
import lib/mofuparser
import lib/httputils

export
  httputils

const
  kByte* = 1024
  mByte* = 1024 * kByte

  defaultBufferSize = 64 * kByte
  maxBodySize = 1 * mByte

type
  mofuwReq* = ref object
    handle: ptr uv_handle_t
    reqLine: HttpReq
    reqHeader*: array[48, headers]
    reqHeaderAddr: ptr array[48, headers]
    reqBody*: string
    reqBodyLen*: int
    params*: StringTableRef
    tmp*: cstring
    buf: pointer

  mofuwRes* = ref object
    handle*: ptr uv_stream_t
    fd: cint
    fs: uv_fs_t
    res*: ptr uv_write_t
    body: uv_buf_t
    req: mofuwReq

  Callback* = proc(req: mofuwReq, res: mofuwRes)

var
  callback*    {.threadvar.}: Callback
  bufferSize*  {.threadvar.}: int

proc getMethod*(req: mofuwReq): string {.inline.} =
  result = ($(req.reqLine.method))[0 .. req.reqLine.methodLen]

proc getPath*(req: mofuwReq): string {.inline.} =
  result = ($(req.reqLine.path))[0 .. req.reqLine.pathLen]

proc getCookie*(req: mofuwReq): string {.inline.} =
  for v in req.reqHeader:
    if v.name == nil: break
    if ($(v.name))[0 .. v.namelen] == "Cookie":
      result = ($(v.value))[0 .. v.valuelen]
      return
  result = ""

proc getReqBody*(req: mofuwReq): string {.inline.} =
  result = $req.reqBody

proc setBufferSize*(size: int) {.inline.} = 
  bufferSize = size

proc afterClose(handle: ptr uv_handle_t) {.cdecl.} =
  dealloc(handle)

proc freeResponse(req: ptr uv_write_t, status: cint) {.cdecl.} =
  dealloc(req)

proc bufAlloc(handle: ptr uv_handle_t, size: csize, buf: ptr uv_buf_t) {.cdecl.} =
  buf.base = cast[ptr char](alloc(bufferSize))
  buf.len = bufferSize

proc mofuw_send*(res: mofuwRes, body: cstring) {.inline.}=
  dealloc(res.req.buf)

  res.body.base = cast[ptr char](body)
  res.body.len = body.len

  if not uv_write(res.res, res.handle, addr(res.body), 1, freeResponse) == 0:
    return

proc notFound*(res: mofuwRes) =
  mofuw_send(res, notFound())

proc read_cb(stream: ptr uv_stream_t, nread: cssize, buf: ptr uv_buf_t) {.cdecl.} =
  if nread == UV_EOF:
    dealloc(buf.base)
    uv_close(cast[ptr uv_handle_t](stream), afterClose)
    return

  elif nread < 0:
    dealloc(buf.base)
    uv_close(cast[ptr uv_handle_t](stream), afterClose)
    return

  var
    request = mofuwReq(reqBody: "")
    response = mofuwRes()

  stream.data = addr(request)

  if nread != bufferSize:
    request.reqBody.add(($(buf.base))[0 .. nread])
    request.reqBodyLen += nread
  else:
    var
      fd: uv_os_fd_t
      buff: array[defaultBufferSize, char]

    discard uv_fileno(cast[ptr uv_handle_t](stream), addr(fd))

    request.reqBody.add($(buf.base))
    request.reqBodyLen += nread

    while true:
      let r = recv(fd.SocketHandle, addr buff[0], bufferSize, 0)

      if r == -1:
        if osLastError().int in {EWOULDBLOCK, EAGAIN}:
          break
        dealloc(buf.base)
        uv_close(cast[ptr uv_handle_t](stream), afterClose)
        return

      request.reqBody.add(addr(buff[0]))
      request.reqBodyLen += r

  request.handle = cast[ptr uv_handle_t](stream)
  request.reqHeaderAddr = request.reqHeader.addr

  response.handle = stream
  response.res = cast[ptr uv_write_t](alloc(sizeof(uv_write_t)))
  response.req = request

  let r = mp_req(addr(request.reqBody[0]), request.reqLine, request.reqHeaderAddr)

  if r <= 0:
    notFound(response)
    uv_close(cast[ptr uv_handle_t](stream), afterClose)
    return

  request.reqBodyLen -= r
  request.reqBody = ($(cast[cstring](cast[int](addr(request.reqBody[0])) + r)))[0 .. request.reqBodyLen - 1]

  if request.reqBodyLen > maxBodySize:
    mofuw_send(response, bodyTooLarge())
    return

  request.buf = buf.base

  callback(request, response)

proc accept_cb(server: ptr uv_stream_t, status: cint) {.cdecl.} =
  if not status == 0:
    echo "error: ", uv_err_name(status), uv_strerror(status), "\n"

  var
    client = cast[ptr uv_stream_t](alloc(sizeof(uv_tcp_t)))

  if not uv_tcp_init(server.loop, cast[ptr uv_tcp_t](client)) == 0:
    return

  if not uv_accept(server, client) == 0:
    return

  if not uv_read_start(client, bufAlloc, read_cb) == 0:
    return

proc updateServerTime(handle: ptr uv_timer_t) {.cdecl.}=
  httputils.updateServerTime()

proc mofuwInit(t: tuple[port: int, backlog: int, cb: Callback, bufSize: int]) =
  var
    loop = cast[ptr uv_loop_t](alloc(sizeof(uv_loop_t)))
    server = cast[ptr uv_tcp_t](alloc(sizeof(uv_tcp_t)))
    timer = cast[ptr uv_timer_t](alloc(sizeof(uv_timer_t)))
    sockaddr: SockAddrIn
    fd: uv_os_fd_t

  callback = t.cb

  setBufferSize(t.bufSize)

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

proc mofuwRUN*(port: int = 8080, backlog: int = 128, buf: int = defaultBufferSize) =
  var th: Thread[tuple[port: int, backlog: int, cb: Callback, bufSize: int]]

  if callback == nil:
    raise newException(Exception, "callback is nil.")

  for i in 0 ..< countProcessors():
    createThread[tuple[port: int, backlog: int, cb: Callback, bufSize: int]](
      th, mofuwInit, (port, backlog, callback, buf)
    )

  joinThread(th)
