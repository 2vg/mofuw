# example app Todo-sqlite3

## require
- nim (devel)
- libuv(1.19)

## usage
need like tmux or multi tab terminal.

```nim
npm i
node app
cd ../
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