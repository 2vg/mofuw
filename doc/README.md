# mofuw's document

> how to use mofuw ?

## API
- `mofuwRun(handler: Callback, port: int = 8080, backlog: int = defaultBacklog(), bufSize: int = 512)`

mofuwRun() is web server start procedure.

There are four arguments.

#### 1st argument

To `handler: Callback`, we pass a callback function that called after parsing the request from the client.

The callback function must be passed in a defined way.

In mofuw it is decided as follows.

```nim
proc foo(req: mofuwReq, res: mofuwRes) {.async.} =
  # doWork()
```

However, writing this every time is troublesome.
(I also think that it is troublesome too :))

So I will change it so that I do not need to write the type of the callback function in the future.

#### 2nd argument

To `port: int = 8080` will pass the port used by the server.

This defaults to 8080, and if you do not pass the specified port you will automatically use 8080.

#### 3rd argment

To `backlog: int = defaultBacklog ()` will pass the maximum number of clients accepted by the server.

By default, the value of SOMAXCONN of OS is used,
Since it is usually best to pass the value of SOMAXCONN of OS, it may be abolished in the future.

#### 4th argment

To `bufSize: int = 512`, we pass the buffer size where mofuw will store the request from the client at once.
By default it is 512, but if there are requests larger than 512, performance may be reduced.
This is the most difficult part to adjust, but I think that it is sufficient from 1024 to 8192