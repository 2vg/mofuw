import
  os,
  uri,
  mofuw,
  macros,
  tables,
  strutils,
  mimetypes,
  asyncfile,
  asyncdispatch

proc fileResp(res: mofuwRes, filePath, file: string) {.async.}=
  let (_, _, ext) = splitFile(filePath)

  if ext == "":
    await res.mofuwSend(makeResp(
      HTTP200,
      "text/plain",
      file
    ))
  else:
    let mime = newMimetypes()

    await res.mofuwSend(makeResp(
      HTTP200,
      mime.getMimetype(ext[1 .. ^1], default = "application/octet-stream"),
      file
    ))

proc staticServe*(req: mofuwReq, res: mofuwRes, rootPath: string): Future[bool] {.async.} =
  var
    state = 0
    reqPath = getPath(req)
    filePath = rootPath

  for k, v in reqPath:
    if v == '.':
      if reqPath[k+1] == '.':
        await res.mofuwSend(badRequest())
        return true

  if filePath[^1] != '/':
    filePath.add("/")
    filePath.add(reqPath[state .. ^1])
  else:
    filePath.add(reqPath[state .. ^1])

  if filePath[^1] != '/':
    if existsDir(filePath):
      # Since the Host header should always exist,
      # Nil check is not done here
      let host = getHeader(req, "Host")

      reqPath.add("/")

      await res.mofuwSend(redirectTo(
        "http://" / host / reqPath
      ))

      return true
    if fileExists(filePath):
      let
        f = openAsync(filePath, fmRead)
        file = await f.readAll()
      close(f)
      await res.fileResp(filePath, file)
      return true
    else:
      return false
  else:
    filePath.add("index.html")
    if fileExists(filePath):
      let
        f = openAsync(filePath, fmRead)
        file = await f.readAll()
      close(f)
      await res.fileResp(filePath, file)
      return true
    else:
      return false

macro routesStatic*(filePath: string, body: untyped): typed =
  result = newStmtList()

  var
    methodCase = newNimNode(nnkCaseStmt)
    methodTables = initTable[string, NimNode]()
    caseTables = initTable[string, NimNode]()

  methodCase.add(
    newCall(
      "getMethod",
      ident("req")
    )
  )

  for i in 0 ..< body.len:
    case body[i].kind
    of nnkCommand:
      let
        cmdName = body[i][0].ident.`$`.normalize.toUpperAscii()
        cmdPath = $body[i][1]

      if not methodTables.hasKey(cmdName):
        methodTables[cmdName] = newNimNode(nnkOfBranch)

        methodTables[cmdName].add(newLit(cmdName))

      if not caseTables.hasKey(cmdName):
        caseTables[cmdName] = newStmtList()

        caseTables[cmdName].add(
          newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("pat"), 
              ident("Pattern"),
              newNimNode(nnkEmpty)
            ),
            newNimNode(nnkIdentDefs).add(
              ident("re"), 
              newNimNode(nnkTupleTy).add(
                newNimNode(nnkIdentDefs).add(
                  ident("matched"), 
                  ident("bool"),
                  newNimNode(nnkEmpty)
                ),
                newNimNode(nnkIdentDefs).add(
                  ident("params"), 
                  ident("StringTableRef"),
                  newNimNode(nnkEmpty)
                )
              ),
              newNimNode(nnkEmpty)
            ),
            newNimNode(nnkIdentDefs).add(
              ident("path"), 
              newNimNode(nnkEmpty),
              newCall(
                "getPath",
                ident("req")
              )
            )
          ),
          newBlockStmt(
            ident("router"),
            newStmtList()
          )
        )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          ident("pat"),
          newCall(
            ident("parsePattern"),
            newStrLitNode(cmdPath)
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          ident("re"),
          newCall(
            ident("match"),
            ident("pat"),
            ident("path")
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newAssignment(
          newDotExpr(
            ident("req"),
            ident("params")
          ),
          newDotExpr(
            ident("re"),
            ident("params")
          )
        )
      )

      caseTables[cmdName].findChild(it.kind == nnkBlockStmt)[1].add(
        newIfStmt(
          (newDotExpr(
            ident("re"),
            ident("matched")
          ),
          body[i][2].add(
            parseStmt("break router")
          ))
        )
      )
    else:
      discard

  var
    nFound = newStmtList()
    elseMethod = newNimNode(nnkElse)

  nFound.add(
    newNimNode(nnkVarSection).add(
      newNimNode(nnkIdentDefs).add(
        ident("fut"), 
        newNimNode(nnkEmpty),
        newCall(
          "staticServe",
          ident("req"),
          ident("res"),
          newStrLitNode(strVal(filePath))
        )
      ),
    ),
    newAssignment(
      newDotExpr(
        ident("fut"),
        ident("callback")
      ),
      newNimNode(nnkLambda).add(
        newNimNode(nnkEmpty),
        newNimNode(nnkEmpty),
        newNimNode(nnkEmpty),
        newNimNode(nnkFormalParams).add(
          newNimNode(nnkEmpty)
        ),
        newNimNode(nnkEmpty),
        newNimNode(nnkEmpty),
        newStmtList().add(
          newNimNode(nnkIfStmt).add(
            newNimNode(nnkElifBranch).add(
              newNimNode(nnkPrefix).add(
                ident("not"),
                newDotExpr(
                  ident("fut"),
                  ident("read")
                )
              ),
              newStmtList().add(
                parseStmt("asyncCheck notFound(res)")
              )
            )
          )
        )
      )
    )
  )

  elseMethod.add(
    newStmtList(
      newNimNode(nnkCommand).add(
        newIdentNode("asyncCheck"),
        newCall(
          "notFound",
          ident("res")
        )
      )
    )
  )

  for k, v in caseTables.pairs:
    v.findChild(it.kind == nnkBlockStmt)[1].add(nFound)
    methodTables[k].add(v)

  for k, v in methodTables.pairs:
    methodCase.add(v)

  methodCase.add(elseMethod)

  result.add(methodCase)