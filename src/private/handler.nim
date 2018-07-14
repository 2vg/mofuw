import core, http, io
import strutils, asyncdispatch

import mofuparser, mofuhttputils

proc handler*(fd: AsyncFD, ip: string) {.async.} =
  var
    ctx =
      when defined ssl:
        if unlikely(not sslCtx.isNil):
          let c = newMofuwCtxSSL(fd, ip, true)
          toSSLSocket(c)
          c
        else:
          newMofuwCtxSSL(fd, ip, true)
      else:
        newMofuwCtx(fd, ip)

    r: int
    buf: array[bufSize, char]
    bigBuf: array[bufSize*2, char]

  block handler:
    while true:
      r = await ctx.mofuwRecvInto(addr buf[0], bufSize)
      if r == 0: ctx.mofuwClose(); return
      r.saveBuffer(ctx, addr buf[0])

      # ##
      # for progress req
      # ##
      if r == bufSize: continue

      case ctx.doubleCRLFCheck()
      of endReq:
        let isGETorHEAD = (ctx.getMethod == "GET") or (ctx.getMethod == "HEAD")

        # for not GET or HEAD METHOD
        if not isGETorHEAD:
          let hasContentLength = ctx.contentLengthCheck()
          if hasContentLength != -2:
            if hasContentLength != -1:
              while not(ctx.buf.len - ctx.bodyStart >= hasContentLength):
                r = await ctx.mofuwRecvInto(addr bigBuf[0], bufSize*2)
                if r == 0: ctx.mofuwClose(); return
                r.saveBuffer(ctx, addr buf[0])
            else:
              # TODO: Content-Length error.
              discard
          elif ctx.getHeader("Transfer-Encoding") == "chunked":
            ctx.mc = MPchunk()
            # Parsing chunks already in the buffer
            var chunkBuf = ctx.body
            var chunkLen = chunkBuf.len
            var parseRes = ctx.mc.mpParseChunk(addr chunkBuf[0], chunkLen)

            if parseRes == -1:
              await ctx.badRequest()
              ctx.mofuwClose()
              break handler

            moveMem(addr ctx.buf[ctx.bodyStart], addr chunkBuf[0], chunkLen)
            ctx.buf.delete(ctx.bodyStart + chunkLen, ctx.buf.len-1)

            # first chunk callback
            mofuwCallback(ctx)

            if parseRes == -2:
              while true:
                var bufLen = await mofuwRecvInto(ctx, addr bigBuf[0], bufSize*2)
                let pRes = ctx.mc.mpParseChunk(addr bigBuf[0], bufLen)
                case pRes
                of -2:
                  let ol = ctx.buf.len
                  ctx.buf.setLen(ol+bufLen)
                  copyMem(addr ctx.buf[ol], addr bigBuf[0], bufLen)
                  # callback loop
                  # chunk processing
                  mofuwCallback(ctx)
                of -1:
                  await ctx.badRequest()
                  ctx.mofuwClose()
                  break handler
                else:
                  if parseRes == 2:
                    break
                  elif parseRes == 1:
                    discard await mofuwRecvInto(ctx, addr bigBuf[0], 1)
                  elif parseRes == 0:
                    discard await mofuwRecvInto(ctx, addr bigBuf[0], 2)

                  # last callback
                  # end chunk process.
                  mofuwCallback(ctx)

            # if end chunk process, we must ready next req
            ctx.buf.setLen(0)
            continue
          else:
            await ctx.badRequest()
            ctx.mofuwClose()
            break handler

          # If the ctx body is large,
          # there is a possibility that
          # the pointer of the buffer has been changed by setLen.
          # So reparse the pointers up to \r\l\r\l.
          discard ctx.mhr.mpParseRequest(addr ctx.buf[0], ctx.buf.len)

        # our callback check.
        mofuwCallback(ctx)

        ctx.buf.delete(0, ctx.bodyStart - 1)
        var remainingBufferSize = ctx.buf.len

        while true:
          if unlikely(isGETorHEAD and (remainingBufferSize > 0)):
            if ctx.doubleCRLFCheck() != endReq:
              await ctx.badRequest()
            else:
              mofuwCallback(ctx)

            ctx.buf.delete(0, ctx.bodyStart - 1)
            remainingBufferSize = ctx.buf.len
          else:
            asyncCheck ctx.mofuwWrite
            ctx.buf.setLen(0)
            break

      of continueReq: continue
      of bodyLarge:
        await ctx.mofuwSend(bodyTooLarge())
        ctx.mofuwClose()
        break handler
      of badReq:
        await ctx.badRequest()
        ctx.mofuwClose()
        break handler
      else: discard