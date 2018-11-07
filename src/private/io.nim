import ctx, ctxpool
import mofuhttputils
import asyncdispatch

when defined ssl:
  import openssl

  proc asyncSSLRecv*(ctx: MofuwCtx, buf: ptr char, bufLen: int): Future[int] =
    var retFuture = newFuture[int]("asyncSSLRecv")
    proc cb(fd: AsyncFD): bool =
      result = true
      let rcv = SSL_read(ctx.sslHandle, buf, bufLen.cint)
      if rcv <= 0:
        retFuture.complete(0)
      else:
        retFuture.complete(rcv)
    addRead(ctx.fd, cb)
    return retFuture

  proc asyncSSLSend*(ctx: MofuwCtx, buf: ptr char, bufLen: int): Future[int] =
    var retFuture = newFuture[int]("asyncSSLSend")
    proc cb(fd: AsyncFD): bool =
      result = true
      let rcv = SSL_write(ctx.sslHandle, buf, bufLen.cint)
      if rcv <= 0:
        retFuture.complete(0)
      else:
        retFuture.complete(rcv)
    addWrite(ctx.fd, cb)
    return retFuture

proc mofuwClose*(ctx: MofuwCtx) =
  when defined ssl:
    if unlikely ctx.isSSL:
      ctx.sslHandle.SSLFree()
  closeSocket(ctx.fd)
  ctx.freeCtx()

proc mofuwRead*(ctx: MofuwCtx, timeOut: int): Future[int] {.async.} =
  let rcvLimit =
    block:
      if unlikely(ctx.buf.len - ctx.bufLen == 0):
        ctx.buf.setLen(ctx.buf.len + ctx.buf.len)
      ctx.buf.len - ctx.bufLen

  when defined ssl:
    if unlikely ctx.isSSL:
      let fut = asyncSSLrecv(ctx, addr ctx.buf[ctx.bufLen], rcvLimit)
      let rcv = 
        if not timeOut == -1:
          let isSuccess = await withTimeout(fut, timeOut)
          if isSuccess: fut.read else: 0
        else:
          await fut
      ctx.bufLen += rcv
      return rcv

  let fut = recvInto(ctx.fd, addr ctx.buf[ctx.bufLen], rcvLimit)
  let rcv = 
    if not timeOut == -1:
      let isSuccess = await withTimeout(fut, timeOut)
      if isSuccess: fut.read else: 0
    else:
      await fut
  ctx.bufLen += rcv
  return rcv

proc mofuwSend*(ctx: MofuwCtx, body: string) {.async.} =
  while unlikely ctx.respLen + body.len > ctx.resp.len:
    ctx.resp.setLen(ctx.resp.len + ctx.resp.len)
  var buf: string
  buf.shallowcopy(body)
  let ol = ctx.respLen
  copyMem(addr ctx.resp[ol], addr buf[0], buf.len)
  ctx.respLen += body.len

proc mofuwWrite*(ctx: MofuwCtx) {.async.} =
  # try send because raise exception.
  # buffer not protect, but
  # mofuwReq have buffer, so this is safe.(?)
  when defined ssl:
    if unlikely ctx.isSSL:
      try:
        discard await asyncSSLSend(ctx, addr(ctx.resp[0]), ctx.respLen)
      except:
        discard
      ctx.respLen = 0
      return

  try:
    await send(ctx.fd, addr(ctx.resp[0]), ctx.respLen)
  except:
    discard
  ctx.respLen = 0

template mofuwResp*(status, mime, body: string): typed =
  asyncCheck ctx.mofuwSend(makeResp(
    status,
    mime,
    body))

template mofuwOK*(body: string, mime: string = "text/plain") =
  mofuwResp(
    HTTP200,
    mime,
    body)