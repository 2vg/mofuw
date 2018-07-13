## Example
## -------
##
## .. code-block::nim
##   import websocket, asynchttpserver, asyncnet, asyncdispatch
##
##   let server = newAsyncHttpServer()
##
##   proc cb(req: Request) {.async.} =
##     let (ws, error) = await verifyWebsocketRequest(req, "myfancyprotocol")
##
##     if ws.isNil:
##       echo "WS negotiation failed: ", error
##       await req.respond(Http400, "Websocket negotiation failed: " & error)
##       req.client.close()
##       return
##
##     echo "New websocket customer arrived!"
##     while true:
##       let (opcode, data) = await ws.readData()
##       try:
##         echo "(opcode: ", opcode, ", data length: ", data.len, ")"
##
##         case opcode
##         of Opcode.Text:
##           waitFor ws.sendText("thanks for the data!")
##         of Opcode.Binary:
##           waitFor ws.sendBinary(data)
##         of Opcode.Close:
##           asyncCheck ws.close()
##           let (closeCode, reason) = extractCloseData(data)
##           echo "socket went away, close code: ", closeCode, ", reason: ", reason
##         else: discard
##       except:
##         echo "encountered exception: ", getCurrentExceptionMsg()
##
##   waitFor server.serve(Port(8080), cb)

import asyncnet, asyncdispatch, strtabs, base64, std/sha1, strutils, sequtils
import ../../../mofuw

import hex

import ./wsshared

proc verifyWebsocketRequest*(ctx: MofuwCtx, protocol = ""):
    Future[tuple[ws: AsyncWebSocket, error: string]] {.async.} =

  ## Verifies the request is a websocket request:
  ## * Supports protocol version 13 only
  ## * Does not support extensions (yet)
  ## * Will auto-negotiate a compatible protocol based on your `protocol` param
  ##
  ## If all validations pass, will give you a tuple (AsyncWebSocket, "").
  ## You can pass in a empty protocol param to not perform negotiation; this is
  ## the equivalent of accepting all protocols the client might request.
  ##
  ## If the client does not send any protocols, but you have given one, the
  ## request will fail.
  ##
  ## If validation FAILS, the response will be (nil, human-readable failure reason).
  ##
  ## After successful negotiation, you can immediately start sending/reading
  ## websocket frames.

  template reterr(err: untyped) =
    result.error = err
    return

  # if req.getHeader.hasKey("sec-websocket-extensions"):
    # TODO: transparently support extensions

  if ctx.getHeader("Sec-WebSocket-Version") != "13":
    reterr "the only supported sec-websocket-version is 13"

  if ctx.getHeader("Sec-WebSocket-Key") == "":
    reterr "no sec-websocket-key provided"

  let isProtocolEmpty = protocol == ""

  if ctx.getHeader("Sec-WebSocket-Protocol") != "":
    if isProtocolEmpty:
      reterr "server does not support protocol negotation"

    block protocolCheck:
      let prot = protocol.toLowerAscii()

      for it in ctx.getHeader("Sec-WebSocket-Protocol").split(", "):
        if prot == it.strip.toLowerAscii():
          break protocolCheck

      reterr "no advertised protocol supported; server speaks `" & protocol & "`"
  elif not isProtocolEmpty:
    reterr "no protocol advertised, but server demands `" & protocol & "`"

  let sh = secureHash(ctx.getHeader("Sec-WebSocket-Key") &
    "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
  let acceptKey = decodeHex($sh).encode
  var msg = "HTTP/1.1 101 Web Socket Protocol Handshake\c\L"
  msg.add("Sec-Websocket-Accept: " & acceptKey & "\c\L")
  msg.add("Connection: Upgrade\c\L")
  msg.add("Upgrade: websocket\c\L")
  if not isProtocolEmpty: msg.add("Sec-Websocket-Protocol: " & protocol & "\c\L")
  msg.add "\c\L"
  await ctx.mofuwSend(msg)
  await ctx.mofuwWrite()

  new(result.ws)
  result.ws.kind = SocketKind.Server
  result.ws.sock = newAsyncSocket(ctx.fd)
  result.ws.protocol = protocol

  result.error = ""