import ctx, newio, newhttp
import asyncdispatch

proc handler*(servectx: ServeCtx, ctx: MofuwCtx) {.async.} =
  while true:
    let rcv = await ctx.mofuwRead()
    if rcv == 0: ctx.mofuwClose(); return
    # buffer is full, request is progress
    if rcv == (ctx.buf.len - ctx.bufLen): continue

    case ctx.doubleCRLFCheck()
    of badReq:
      await ctx.badRequest()
      ctx.mofuwClose()
      return
    of bodyLarge:
      await ctx.bodyTooLarge()
      ctx.mofuwClose()
      return
    of continueReq:
      continue
    of endReq:
      let isGETorHEAD = (ctx.getMethod == "GET") or (ctx.getMethod == "HEAD")

      if not isGETorHEAD:
        let res = await haveBodyHandler(ctx, servectx.handler)
        if not res: return
        continue

      await servectx.handler(ctx)

      # for pipeline request
      var remainingBufferSize = ctx.bufLen - ctx.bodyStart
      while true:
        if unlikely(isGETorHEAD and (remainingBufferSize > 0)):
          ctx.currentBufPos = ctx.bodyStart
          if ctx.doubleCRLFCheck() != endReq:
            await ctx.badRequest()
          else:
            await servectx.handler(ctx)
          remainingBufferSize = ctx.bufLen - ctx.bodyStart
        else:
          asyncCheck ctx.mofuwWrite()
          ctx.bufLen = 0
          break