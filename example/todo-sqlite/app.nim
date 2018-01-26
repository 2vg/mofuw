import mofuw
import middleware/mofuw_router
import lib/httputils

import json
import db_sqlite
import random
import os

let
  router = newMofuwRouter()
  db = open("example/todo-sqlite/todo.db", nil, nil, nil)

if not fileExists("example/todo-sqlite/todo.db"):
  db.exec(sql("""create table todo (
 　              Id   INTEGER PRIMARY KEY,
 　　            todo TEXT)"""))

callback = proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  mofuwRouting(router, req, res)

router.mofuwGET("/api/todo/get", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  var json = %* []

  for r in db.rows(sql"select * from todo", []):
    json.add(%* {"todo_id": r[1], "todo": r[2]})

  res.mofuw_send(
    addBody(
      addHeader(
        makeRespNoBody(HTTP200),
        @[
          ("Access-Control-Allow-Origin", "*")
        ]
      ),
      "application/json",
      $json
    )
  )
)

router.mofuwPOST("/api/todo/add", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  var
    json: JsonNode
    resp = %* []

  try:
    json = parseJson(getReqBody(req))
  except:
    res.mofuw_send(badRequest())
    return

  randomize()

  if db.tryInsertId(sql"INSERT INTO todo (todo_id, todo) VALUES (?, ?)",
                    rand(99999999), json["todo"].str) == -1:
    res.mofuw_send(badRequest())
    return

  for r in db.rows(sql"select * from todo", []):
    resp.add(%* {"todo_id": r[1], "todo": r[2]})

  res.mofuw_send(
    addBody(
      addHeader(
        makeRespNoBody(HTTP200),
        @[
          ("Access-Control-Allow-Origin", "*")
        ]
      ),
      "application/json",
      $resp
    )
  )
)

router.mofuwPOST("/api/todo/delete", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  var
    json: JsonNode
    resp = %* []

  try:
    json = parseJson(getReqBody(req))
  except:
    res.mofuw_send(badRequest())
    return

  if not db.tryExec(sql("""DELETE FROM todo WHERE todo_id=?"""), json["todo_id"].str):
    res.mofuw_send(badRequest())
    return

  for r in db.rows(sql"select * from todo", []):
    resp.add(%* {"todo_id": r[1], "todo": r[2]})

  res.mofuw_send(
    addBody(
      addHeader(
        makeRespNoBody(HTTP200),
        @[
          ("Access-Control-Allow-Origin", "*")
        ]
      ),
      "application/json",
      $resp
    )
  )
)

router.mofuwOPTIONS("/api/todo/add", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  res.mofuw_send(
    addBody(
      addHeader(
        makeRespNoBody(HTTP200),
        @[
          ("Access-Control-Allow-Origin", "*"),
          ("Access-Control-Max-Age", "86400"),
          ("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,HEAD,OPTIONS"),
          ("Access-Control-Allow-Headers", "*")
        ]
      ),
      "text/plain",
      ""
    )
  )
)

router.mofuwOPTIONS("/api/todo/delete", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  res.mofuw_send(
    addBody(
      addHeader(
        makeRespNoBody(HTTP200),
        @[
          ("Access-Control-Allow-Origin", "*"),
          ("Access-Control-Max-Age", "86400"),
          ("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,HEAD,OPTIONS"),
          ("Access-Control-Allow-Headers", "*")
        ]
      ),
      "text/plain",
      ""
    )
  )
)

mofuwRUN(8080)
