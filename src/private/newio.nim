import ctx, ctxpool
import asyncdispatch

proc mofuwClose*(ctx: MofuwCtx) =
  closeSocket(ctx.fd)
  when defined ssl:
    if unlikely ctx.isSSL:
      discard ctx.sslHandle.SSLShutdown()
      ctx.sslHandle.SSLFree()
  ctx.freeCtx()

proc mofuwRead*(ctx: MofuwCtx): Future[int] {.async.} =
  let rcvLimit = ctx.buf.len - ctx.bufLen
  if rcvLimit == 0: ctx.buf.setLen(ctx.buf.len + ctx.buf.len)

  when defined ssl:
    if unlikely ctx.isSSL:
      let rcv = await asyncSSLrecv(ctx, addr ctx.buf[ctx.bufLen], rcvLimit)
      ctx.bufLen += rcv
      return rcv

  let rcv = await recvInto(ctx.fd, addr ctx.buf[ctx.bufLen], rcvLimit)
  ctx.bufLen += rcv
  return rcv

proc mofuwSend*(ctx: MofuwCtx, body: string) {.async.} =
  if unlikely ctx.respLen + body.len > ctx.resp.len:
    ctx.resp.setLen(ctx.resp.len + ctx.resp.len)
  ctx.resp.add(body)
  ctx.respLen += body.len

proc mofuwWrite*(ctx: MofuwCtx) {.async.} =
  # try send because raise exception.
  # buffer not protect, but
  # mofuwReq have buffer, so this is safe.(?)
  when defined ssl:
    if unlikely ctx.isSSL:
      let fut = asyncSSLSend(ctx, addr(ctx.resp[0]), ctx.respLen)
      yield fut
      if fut.failed:
        ctx.mofuwClose()
      ctx.resp.setLen(0)
      return

  let fut = send(ctx.fd, addr(ctx.resp[0]), ctx.respLen)
  yield fut
  if fut.failed:
    ctx.mofuwClose()
  ctx.respLen = 0

template mofuwResp*(status, mime, body: string): typed =
  asyncCheck ctx.mofuwSend(respGen(
    status,
    mime,
    body))

template mofuwOK*(body: string, mime: string = "text/plain") =
  mofuwResp(
    HTTP200,
    mime,
    body)