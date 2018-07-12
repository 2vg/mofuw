import core, http, io
import strutils, asyncdispatch

import mofuparser, mofuhttputils

proc handler*(fd: AsyncFD, ip: string) {.async.} =
  var
    request = mofuwReq(buf: "", mhr: MPHTTPReq())
    response =
      when defined ssl:
        if unlikely(not sslCtx.isNil):
          let res = mofuwRes(fd: fd, isSSL: true, sslCtx: sslCtx)
          toSSLSocket(res)
          res
        else:
          mofuwRes(fd: fd, isSSL: false)
      else:
        mofuwRes(fd: fd)

    r: int
    buf: array[bufSize, char]
    bigBuf: array[bufSize*2, char]

  block handler:
    while true:
      r.recvCheck(response, addr buf[0], bufSize)
      r.saveBuffer(request, addr buf[0])

      case request.doubleCRLFCheck()
      of endReq:
        let isGETorHEAD = (request.getMethod == "GET") or (request.getMethod == "HEAD")

        # for not GET or HEAD METHOD
        if not isGETorHEAD:
          let hasContentLength = request.contentLengthCheck()
          if hasContentLength != -2:
            if hasContentLength != -1:
              while not(request.buf.len - request.bodyStart >= hasContentLength):
                r.recvCheck(response, addr bigBuf[0], bufSize*2)
                r.saveBuffer(request, addr buf[0])
            else:
              # TODO: Content-Length error.
              discard
          elif request.getHeader("Transfer-Encoding") == "chunked":
            request.mc = MPchunk()
            # Parsing chunks already in the buffer
            var chunkBuf = request.body
            var chunkLen = chunkBuf.len
            var parseRes = request.mc.mpParseChunk(addr chunkBuf[0], chunkLen)

            if parseRes == -1:
              await response.badRequest()
              response.mofuwClose()
              break handler

            moveMem(addr request.buf[request.bodyStart], addr chunkBuf[0], chunkLen)
            request.buf.delete(request.bodyStart + chunkLen, request.buf.len-1)

            # first chunk callback
            mofuwCallback(request, response)

            if parseRes == -2:
              while true:
                var bufLen = await mofuwRecvInto(response, addr bigBuf[0], bufSize*2)
                let pRes = request.mc.mpParseChunk(addr bigBuf[0], bufLen)
                case pRes
                of -2:
                  let ol = request.buf.len
                  request.buf.setLen(ol+bufLen)
                  copyMem(addr request.buf[ol], addr bigBuf[0], bufLen)
                  # callback loop
                  # chunk processing
                  mofuwCallback(request, response)
                of -1:
                  await response.mofuwSend(badRequest())
                  response.mofuwClose()
                  break handler
                else:
                  if parseRes == 2:
                    break
                  elif parseRes == 1:
                    discard await mofuwRecvInto(response, addr bigBuf[0], 1)
                  elif parseRes == 0:
                    discard await mofuwRecvInto(response, addr bigBuf[0], 2)

                  # last callback
                  # end chunk process.
                  mofuwCallback(request, response)

            # if end chunk process, we must ready next request
            request.buf.setLen(0)
            continue
          else:
            await response.mofuwSend(badRequest())
            response.mofuwClose()
            break handler

          # If the request body is large,
          # there is a possibility that
          # the pointer of the buffer has been changed by setLen.
          # So reparse the pointers up to \r\l\r\l.
          discard mpParseRequest(addr request.buf[0], request.mhr)

        # our callback check.
        mofuwCallback(request, response)

        # for pipeline ?
        request.buf.delete(0, request.bodyStart - 1)

        var remainingBufferSize = request.buf.len

        while true:
          if unlikely(isGETorHEAD and (remainingBufferSize > 0)):
            if request.doubleCRLFCheck() != endReq: break

            mofuwCallback(request, response)

            request.buf.delete(0, request.bodyStart - 1)
            remainingBufferSize = request.buf.len
          else:
            request.buf.setLen(0)
            break

      of continueReq: continue
      of bodyLarge:
        await response.mofuwSend(bodyTooLarge())
        response.mofuwClose()
        break handler
      of badReq:
        await response.mofuwSend(badRequest())
        response.mofuwClose()
        break handler
      else: discard