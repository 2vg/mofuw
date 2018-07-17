import ctx
import deques
import mofuparser

var ctxQueue {.threadvar.}: Deque[MofuwCtx]

proc initCtxPool*(readSize, writeSize: int, cap: int) =
  ctxQueue = initDeque[MofuwCtx](cap)

  #[
    for guard memory fragmentation.
  ]#
  var ctxArray = newSeq[MofuwCtx](cap)

  for i in 0 ..< cap:
    ctxArray[i] = newMofuwCtx(readSize, writeSize)
    GC_ref(ctxArray[i])
    ctxQueue.addFirst(ctxArray[i])

proc createCtx*(readSize, writeSize: int): MofuwCtx =
  result = newMofuwCtx(readSize, writeSize)
  GC_ref(result)

proc getCtx*(readSize, writeSize: int): MofuwCtx =
  if ctxQueue.len > 0:
    return ctxQueue.popFirst()
  else:
    return createCtx(readSize, writeSize)

proc freeCtx*(ctx: MofuwCtx) =
  ctxQueue.addLast(ctx)