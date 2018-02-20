import mofuw
import middleware/router/mofuwRouter
import middleware/staticServe/mofuwStaticServe

import json
import db_sqlite
import random
import os

let
  router = newMofuwRouter()
  db = open("todo.db", nil, nil, nil)
  f = open("todo.db")

if f.getFileSize() == 0:
  db.exec(sql("""create table todo (id, todo_id integer, todo text)"""))

f.close()

callback = proc(req: mofuwReq, res: mofuwRes) =
  if not serveStatic(req, res, "public"):
    mofuwRouting(router, req, res)

router.mofuwGET("/api/todo/get", proc(req: mofuwReq, res: mofuwRes) =
  var json = %* []

  try:
    for r in db.rows(sql"select * from todo", []):
      json.add(%* {"todo_id": r[1], "todo": r[2]})
  except:
    res.mofuw_send(notFound())

  res.mofuw_send(makeResp(
    HTTP200,
    "application/json",
    $json
  ))
)

router.mofuwPOST("/api/todo/add", proc(req: mofuwReq, res: mofuwRes) =
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

  res.mofuw_send(makeResp(
    HTTP200,
    "application/json",
    $resp
  ))
)

router.mofuwPOST("/api/todo/delete", proc(req: mofuwReq, res: mofuwRes) =
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

  res.mofuw_send(makeResp(
    HTTP200,
    "application/json",
    $resp
  ))
)

mofuwRUN(8080)
