import lib/nimuv
import lib/mofuparser

const
  kByte = 1024
  mByte = 1024 * kByte

  maxBodySize = 1 * mByte

type
  #mofuw_t = object
  #  server: uv_tcp_t
    

  http_req = object
    handle: ptr uv_handle_t
    req_line: HttpReq
    req_header: array[64, headers]
    req_header_addr: ptr http_req.req_header
    # req_body: array[maxBodySize, char]
    # req_body_len: int

  http_res = object
    fd: cint
    
  router = object
    `method`: string
    path: string
    cb: proc(req: http_req)

proc getMethod(req: http_req): string =
  return cast[string](req.req_line.method)[0 .. req.req_line.methodLen]

proc getPath(req: http_req): string =
  return cast[string](req.req_line.path)[0 .. req.req_line.pathLen]

var
  server: uv_tcp_t
  loop: ptr uv_loop_t
  sockaddr: SockAddrIn
  ROUTER: seq[router]
  body: cstring = "HTTP/1.1 200 OK" & "\r\L" &
                  "Connection: keep-alive" & "\r\L" &
                  "Content-Length: 11"  & "\r\L" &
                  "Content-Type: text/plain; charset=utf-8" & "\r\L" & "\r\L" &
                  "Hello World"

  ev_close: uv_close_cb = proc(handle: ptr uv_handle_t) {.cdecl.} =
    return

  ev_alloc: uv_alloc_cb = proc(handle: ptr uv_handle_t, size: csize, buf: ptr uv_buf_t) {.cdecl.} = 
    buf[].base = alloc(size)
    buf[].len = size

  return_res: proc(request: http_req)
    # let m = getMethod(request)
    # 

  ev_read: uv_read_cb = proc(stream: ptr uv_stream_t, nread: cssize, buf: ptr uv_buf_t) {.cdecl.} =
    if nread.int <= 0:
      dealloc(buf.base)
      return

    var request: http_req

    stream.data = request

    let r = mp_req(cast[cstring](buf.base)[0].addr, request.req_line, request.req_header_addr)

    if r < 0:
      dealloc(buf.base)
      uv_close(cast[ptr uv_handle_t](stream), ev_close)
      return

    #request.req_body = cast[cstring](buf.base)[r]
    #request.req_body_len = cast[cstring](buf.base).len - r - 1

    return_res(request)
    dealloc(buf.base)

  ev_connection: uv_connection_cb = proc(server: ptr uv_stream_t, status: cint) {.cdecl.} =
    if not status == 0: echo "error: ", uv_err_name(status), uv_strerror(status), "\n"

    var client = cast[ptr uv_stream_t](alloc(sizeof(uv_tcp_t)))

    discard uv_tcp_init(loop, cast[ptr uv_tcp_t](client))
    discard uv_tcp_simultaneous_accepts(cast[ptr uv_tcp_t](client), 1)
    discard uv_accept(server, client)
    discard uv_tcp_nodelay(cast[ptr uv_tcp_t](client), 1)
    discard uv_read_start(client, ev_alloc, ev_read)

######
# MAIN
######
proc mofuw_init(port: int = 8080, backlog: int = 128, cb: proc(request: http_req)) =
  loop = uv_default_loop()

  discard uv_ip4_addr("0.0.0.0".cstring, port.cint, sockaddr.addr)
  discard uv_tcp_init(loop, server.addr)

  discard uv_tcp_nodelay(server.addr, 1)

  return_res = cb
  
  discard uv_tcp_bind(server.addr, cast[ptr SockAddr](sockaddr.addr), 0)
  discard uv_listen(cast[ptr uv_stream_t](addr server), backlog.cint, ev_connection)

proc mofuw_run() =
  discard uv_run(loop, UV_RUN_DEFAULT)

proc mofuw_GET(path: string, cb: proc(req: http_req)) =
  var r: router

  r.method = "GET"
  r.path = path
  r.cb = cb

  ROUTER.add(r)


# mofuw_init(8080, 1024)
# proc handler(req: http_req) =
#   hoge
# mofuw_GET("/", handler)
# mofuw_run((proc() = 
#   hoge
#))