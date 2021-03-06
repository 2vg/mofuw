import ctx, handler
import macros, strutils

macro handlerMacro*(body: untyped): untyped =
  result = newStmtList()

  let lam = newNimNode(nnkProcDef).add(
    ident"mofuwHandler",newEmptyNode(),newEmptyNode(),
    newNimNode(nnkFormalParams).add(
      newEmptyNode(),
      newIdentDefs(ident"ctx", ident"MofuwCtx")
    ),
    newNimNode(nnkPragma).add(ident"async"),
    newEmptyNode(),
    body
  )

  result.add(lam)

macro mofuwLambda(body: untyped): untyped =
  result = newStmtList()

  let lam = newNimNode(nnkLambda).add(
    newEmptyNode(),newEmptyNode(),newEmptyNode(),
    newNimNode(nnkFormalParams).add(
      newEmptyNode(),
      newIdentDefs(ident"ctx", ident"MofuwCtx")
    ),
    newNimNode(nnkPragma).add(ident"async"),
    newEmptyNode(),
    body
  )

  result.add(lam)

macro routesBase*(body: untyped): untyped =
  var staticPath = ""

  result = newStmtList()
  result.add(parseStmt("""
    let mofuwRouter = newRouter[proc(ctx: MofuwCtx): Future[void]]()
  """))

  # mofuwRouter.map(
  #   proc(ctx: MofuwCtxs) {.async.} =
  #     body
  # , "METHOD", "PATH")
  for i in 0 ..< body.len:
    case body[i].kind
    of nnkCommand:
      let methodName = ($body[i][0]).normalize.toLowerAscii()
      let pathName = $body[i][1]
      result.add(
        newCall("map", ident"mofuwRouter",
          getAst(mofuwLambda(body[i][2])),
          newLit(methodName),
          newLit(pathName)
        )
      )
    of nnkCall:
      let call = ($body[i][0]).normalize.toLowerAscii()
      let path = $body[i][1]
      if call == "serve":
        staticPath.add(path)
    else:
      discard

  result.add(newCall(ident"compress", ident"mofuwRouter"))

  let handlerBody = newStmtList()

  handlerBody.add(
    parseStmt"""
    var headers = ctx.toHttpHeaders()
    """,
    parseStmt"""
    let r = mofuwRouter.route(ctx.getMethod, parseUri(ctx.getPath), headers)
    """
  )

  let staticRoutes =
    if staticPath != "":
      parseStmt(
        "if not (await staticServe(ctx, \"" & staticPath & "\")): await ctx.mofuwSend(notFound())")
    else:
      parseStmt("await ctx.mofuwSend(notFound())")

  # if r.status == routingFailure:
  #   await ctx.mofuwSned(notFound())
  # else:
  #   req.setParam(r.arguments.pathArgs)
  #   req.setQuery(r.arguments.queryArgs)
  #   await r.handler(req, ctx)
  handlerBody.add(
    newNimNode(nnkIfStmt).add(
      newNimNode(nnkElifBranch).add(
        infix(
          newDotExpr(ident"r", ident"status"),
          "==",
          ident"routingFailure"
        ),
        newStmtList().add(
          staticRoutes
        )
      ),
      newNimNode(nnkElse).add(
        newStmtList(
          newCall(
            newDotExpr(ident"ctx", ident"setParam"),
            newDotExpr(newDotExpr(ident"r", ident"arguments"), ident"pathArgs")
          ),
          newCall(
            newDotExpr(ident"ctx", ident"setQuery"),
            newDotExpr(newDotExpr(ident"r", ident"arguments"), ident"queryArgs")
          ),
          newNimNode(nnkCommand).add(
            ident"await",
            newCall(
              newDotExpr(ident"r", ident"handler"),
              ident"ctx"
            )
          )
        )
      )
    )
  )

  result.add(handlerBody)

macro routes*(body: untyped): untyped =
  let base = getAst(routesBase(body))
  result = getAst(handlerMacro(base))

when defined vhost:
  macro vhosts*(ctx: ServeCtx, body: untyped): untyped =
    result = newStmtList()

    for i in 0 ..< body.len:
      case body[i].kind
      of nnkCommand:
        let callName = ($body[i][0]).normalize.toLowerAscii()
        let serverName = $body[i][1]
        if callName != "host": raise newException(Exception, "can't define except Host.")

        let lam =
          if $body[i][2][0][0].toStrLit == "routes":
            newNimNode(nnkLambda).add(
              newEmptyNode(),newEmptyNode(),newEmptyNode(),
              newNimNode(nnkFormalParams).add(
                newEmptyNode(),
                newIdentDefs(ident"ctx", ident"MofuwCtx")
              ),
              newNimNode(nnkPragma).add(ident"async"),
              newEmptyNode(),
              getAst(routesBase(body[i][2][0][1]))
            )
          else:
            newNimNode(nnkLambda).add(
              newEmptyNode(),newEmptyNode(),newEmptyNode(),
              newNimNode(nnkFormalParams).add(
                newEmptyNode(),
                newIdentDefs(ident"ctx", ident"MofuwCtx")
              ),
              newNimNode(nnkPragma).add(ident"async"),
              newEmptyNode(),
              body[i][2]
            )

        result.add(
          newCall(
            "registerCallBack",
            `ctx`,
            ident(serverName).toStrLit,
            lam))
      else:
        discard

    var handler = quote do:
      let header = ctx.getHeader("Host")
      let table = ctx.getCallBackTable()
      if table.hasKey(header):
        await table[header](ctx)
      else:
        for cb in table.values:
          await cb(ctx)

    let vhostHandler = getAst(mofuwLambda(handler))

    result.add(quote do:
      `ctx`.handler = `vhostHandler`
      `ctx`.serve()
    )