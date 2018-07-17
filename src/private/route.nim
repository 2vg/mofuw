import handler
import macros, strutils

macro mofuwHandler*(body: untyped): untyped =
  result = newStmtList()

  let lam = newNimNode(nnkProcDef).add(
    ident"mofuwHandler",newEmptyNode(),newEmptyNode(),
    newNimNode(nnkFormalParams).add(
      newEmptyNode(),
      newIdentDefs(ident"req", ident"mofuwReq"),
      newIdentDefs(ident"res", ident"mofuwRes")
    ),
    newNimNode(nnkPragma).add(ident"async"),
    newEmptyNode(),
    body
  )

  result.add(lam)

macro mofuwLambda(body: untyped): untyped =
  result = newStmtList()

  let lam = newNimNode(nnkLambda).add(
    ident"mofuwHandler",newEmptyNode(),newEmptyNode(),
    newNimNode(nnkFormalParams).add(
      newEmptyNode(),
      newIdentDefs(ident"req", ident"mofuwReq"),
      newIdentDefs(ident"res", ident"mofuwRes")
    ),
    newNimNode(nnkPragma).add(ident"async"),
    newEmptyNode(),
    body
  )

  result.add(lam)

macro routes*(body: untyped): untyped =
  var staticPath = ""

  result = newStmtList()
  result.add(parseStmt("""
    let mofuwRouter = newRouter[proc(req: mofuwReq, res: mofuwRes): Future[void]]()
  """))

  # mofuwRouter.map(
  #   proc(req: mofuwReq, res: mofuwRes) {.async.} =
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
    var headers = req.toHttpHeaders()
    """,
    parseStmt"""
    let r = mofuwRouter.route(req.getMethod, parseUri(req.getPath), headers)
    """
  )

  let staticRoutes =
    if staticPath != "":
      parseStmt(
        "if not (await staticServe(req, res, \"" & staticPath & "\")): await res.mofuwSend(notFound())")
    else:
      parseStmt("await res.mofuwSend(notFound())")

  # if r.status == routingFailure:
  #   await res.mofuwSned(notFound())
  # else:
  #   req.setParam(r.arguments.pathArgs)
  #   req.setQuery(r.arguments.queryArgs)
  #   await r.handler(req, res)
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
            newDotExpr(ident"req", ident"setParam"),
            newDotExpr(newDotExpr(ident"r", ident"arguments"), ident"pathArgs")
          ),
          newCall(
            newDotExpr(ident"req", ident"setQuery"),
            newDotExpr(newDotExpr(ident"r", ident"arguments"), ident"queryArgs")
          ),
          newNimNode(nnkCommand).add(
            ident"await",
            newCall(
              newDotExpr(ident"r", ident"handler"),
              ident"req", ident"res"
            )
          )
        )
      )
    )
  )

  result.add(getAst(mofuwHandler(handlerBody)))

  result.add(parseStmt("""
    setCallback(mofuwHandler)
  """))