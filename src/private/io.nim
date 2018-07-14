import core
import asyncdispatch

# ##
# close socket template
# ##
template mofuwClose*(ctx: MofuwCtx) =
  when defined ssl:
    try:
      closeSocket(ctx.fd)
    except:
      # TODO send error logging
      discard
    if unlikely ctx.isSSL:
      discard ctx.sslHandle.SSLShutdown()
      ctx .sslHandle.SSLFree()
  else:
    try:
      closeSocket(ctx.fd)
    except:
      # TODO send error logging
      discard

# ##
# recv template
# ##
template mofuwRecvInto*(ctx: MofuwCtx, buf: pointer, bufLen: int): untyped =
  when defined ssl:
    if ctx.isSSL:
      asyncSSLrecv(ctx, cast[ptr char](buf), bufLen)
    else:
      recvInto(ctx.fd, buf, bufLen)
  else:
    recvInto(ctx.fd, buf, bufLen)

# ##
# main send proc
# ##
proc mofuwWrite*(ctx: MofuwCtx) {.async.} =
  var buf: string
  buf.shallowcopy(ctx.resp)

  # try send because raise exception.
  # buffer not protect, but
  # mofuwReq have buffer, so this is safe.(?)
  when defined ssl:
    if unlikely ctx.isSSL:
      let fut = asyncSSLSend(ctx, addr(buf[0]), buf.len)
      yield fut
      if fut.failed:
        ctx.mofuwClose()
      ctx.resp.setLen(0)
      return

  let fut = send(ctx.fd, addr(buf[0]), buf.len)
  yield fut
  if fut.failed:
    ctx.mofuwClose()
  ctx.resp.setLen(0)

proc mofuwSend*(ctx: MofuwCtx, body: string) {.async.} =
  var b: string
  b.shallowcopy(body)

  let ol = ctx.resp.len
  ctx.resp.setLen(ol+body.len)
  copyMem(addr ctx.resp[ol], addr b[0], body.len)

template mofuwResp*(status, mime, body: string): typed =
  asyncCheck ctx.mofuwSend(makeResp(
    status,
    mime,
    body))

# ##
# return HTTP200
# ##
template mofuwOK*(body: string, mime: string = "text/plain") =
  mofuwResp(
    HTTP200,
    mime,
    body)