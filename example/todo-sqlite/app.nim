import mofuw, json, db_sqlite, random, os

let
  db = open("todo.db", nil, nil, nil)
  file = open("todo.db")

if file.getFileSize() == 0:
  db.exec(sql("""create table todo (id, todo_id integer, todo text)"""))

file.close()

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routesStatic "public":
    get "/hello":
      mofuwResp(HTTP200, "text/plain", "Hello, World!")
    get "/api/todo/get":
      var json = %* []

      try:
        for r in db.rows(sql"select * from todo", []):
          json.add(%* {"todo_id": r[1], "todo": r[2]})
      except:
        asyncCheck res.mofuwSend2(notFound())

      mofuwResp(
        HTTP200,
        "application/json",
        $json
      )

    post "/api/todo/add":
      var
        json: JsonNode
        resp = %* []

      try:
        json = parseJson(req.body)
      except:
        asyncCheck res.mofuwSend2(notFound())
        return

      randomize()

      if db.tryInsertId(sql"INSERT INTO todo (todo_id, todo) VALUES (?, ?)",
                        rand(99999999), json["todo"].str) == -1:
        asyncCheck res.mofuw_send2(badRequest())
        return

      for r in db.rows(sql"select * from todo", []):
        resp.add(%* {"todo_id": r[1], "todo": r[2]})

      mofuwResp(
        HTTP200,
        "application/json",
        $resp
      )

    post "/api/todo/delete":
      var
        json: JsonNode
        resp = %* []

      try:
        json = parseJson(req.body)
      except:
        asyncCheck res.mofuwSend2(notFound())
        return

      if not db.tryExec(sql("""DELETE FROM todo WHERE todo_id=?"""), json["todo_id"].str):
        asyncCheck res.mofuw_send2(badRequest())
        return

      for r in db.rows(sql"select * from todo", []):
        resp.add(%* {"todo_id": r[1], "todo": r[2]})

      mofuwResp(
        HTTP200,
        "application/json",
        $resp
      )

handler.mofuwRun(8080)