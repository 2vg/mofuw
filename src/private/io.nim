import core
import asyncdispatch

# ##
# close socket template
# ##
template mofuwClose*(res: mofuwRes) =
  when defined ssl:
    try:
      closeSocket(res.fd)
    except:
      # TODO send error logging
      discard
    if unlikely res.isSSL:
      discard res.sslHandle.SSLShutdown()
      res.sslHandle.SSLFree()
  else:
    try:
      closeSocket(res.fd)
    except:
      # TODO send error logging
      discard

# ##
# recv template
# ##
template mofuwRecvInto*(res: mofuwRes, buf: pointer, bufLen: int): untyped =
  when defined ssl:
    if res.isSSL:
      asyncSSLrecv(res, cast[ptr char](buf), bufLen)
    else:
      recvInto(res.fd, buf, bufLen)
  else:
    recvInto(res.fd, buf, bufLen)

# ##
# main send proc
# ##
proc mofuwWrite*(res: mofuwRes) {.async.} =
  var buf: string
  buf.shallowcopy(res.resp)

  # try send because raise exception.
  # buffer not protect, but
  # mofuwReq have buffer, so this is safe.(?)
  when defined ssl:
    if unlikely res.isSSL:
      let fut = asyncSSLSend(res, addr(buf[0]), buf.len)
      yield fut
      if fut.failed:
        res.mofuwClose()
      res.resp.setLen(0)
      return

  let fut = send(res.fd, addr(buf[0]), buf.len)
  yield fut
  if fut.failed:
    res.mofuwClose()
  res.resp.setLen(0)

proc mofuwSend*(res: mofuwRes, body: string) {.async.} =
  var b: string
  b.shallowcopy(body)

  let ol = res.resp.len
  res.resp.setLen(ol+body.len)
  copyMem(addr res.resp[ol], addr b[0], body.len)

template mofuwResp*(status, mime, body: string): typed =
  asyncCheck res.mofuwSend(makeResp(
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