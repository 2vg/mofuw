import ../../src/mofuw
import strutils, tables

proc mytest*(x:string):string=
  result="hello " & x
  
type
  appHandler* =ref object of RootObj
    proctable* :Table[string,proc(x:string):string]
  
proc initProcTable* (this:appHandler):void {.inline.}=
  this.proctable["mytest"]=mytest
  
proc call* (this:appHandler,ctx:MofuwCtx):void {.inline.}=
  var webresult:string=this.proctable[ctx.body]("world")
  mofuwResp(HTTP200,"text/plain",webresult)

var myapp {.threadvar.}: appHandler

myapp = appHandler()
myapp.initProcTable()

routes:
  post "/test":
    myapp.call(ctx)

newServeCtx(
  port = 8080,
  handler = mofuwHandler
).serve()
