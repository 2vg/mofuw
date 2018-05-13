import mofuw, httpauth

# Create a backend as needed and an HTTPAuth instance
let backend = newSQLBackend("sqlite://./authdemo.sqlite3")
var auth = newHTTPAuth("localhost", backend)

# Create admin user - you need to run this only once
auth.initialize_admin_user(password="demo")

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
    post "/login":
      # Perform login
      let headers = req.toHttpHeaders()
      var
        andCharPlace = 0
        loginID = ""
        pw = ""
      for i in 9 ..< req.body.len:
        if req.body[i] == '&':
          andCharPlace = i
          break
        loginID.add(req.body[i])
      for i in andCharPlace+10 ..< req.body.len:
        pw.add(req.body[i])
      echo loginID
      echo pw
      auth.headers_hook(headers)
      try:
        auth.login(loginID, pw)
        mofuwResp(HTTP200, "text/html", "Success")
      except LoginError:
        mofuwResp(HTTP200, "text/html", "Failed")

handler.mofuwRun(8080)