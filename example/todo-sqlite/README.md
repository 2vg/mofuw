# example app Todo-sqlite3

## require
- nim (devel)
- libuv(1.18)
- sqlite db(see app.nim and, if want create db, comment out.)

## usage
```nim
nim c -r -d:release app
```

## routing
- GET
  - /api/todo/get
- POST
  - /api/todo/add
  - /api/todo/delete
- OPTIONS (for CORS)
  - /api/todo/add
  - /api/todo/delete

## usage api
#### POST
`/api/todo/add` examle body:
`{"todo":"test"}`

`/api/todo/delete` examle body:
`{"todo_id":"12345678"}`