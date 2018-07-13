import ../../src/mofuw/websocket, ../../src/mofuw

mofuwHandler:
  let (ws, error) = await verifyWebsocketRequest(ctx)

  if ws.isNil:
    echo "WS negotiation failed: ", error
    mofuwResp(HTTP400, "text/plain", "Websocket negotiation failed: " & error)
    return

  echo "New websocket customer arrived!"
  while true:
    let (opcode, data) = await ws.readData()
    try:
      echo "(opcode: ", opcode, ", data length: ", data.len, ")"

      case opcode
      of Opcode.Text:
        waitFor ws.sendText("thanks for the data!")
      of Opcode.Binary:
        waitFor ws.sendBinary(data)
      of Opcode.Close:
        asyncCheck ws.close()
        let (closeCode, reason) = extractCloseData(data)
        echo "socket went away, close code: ", closeCode, ", reason: ", reason
      else: discard
    except:
      echo "encountered exception: ", getCurrentExceptionMsg()

mofuwHandler.mofuwRun(8080)