import core
import times, json, strutils

proc nowDateTime: (string, string) =
  var ti = now()
  result = 
    ($ti.year & '-' & intToStr(ord(ti.month), 2) &
    '-' & intToStr(ti.monthday, 2),
    intToStr(ti.hour, 2) & ':' & intToStr(ti.minute, 2) &
    ':' & intToStr(ti.second, 2))

# ##
# still develop
# ##
proc serverLogging*(req: mofuwReq, format: string = nil) =
  let (date, time) = nowDateTime()
  if format.isNil:
    var log = %*{
      "address": req.ip,
      "request_method": req.getMethod,
      "request_path": req.getPath,
      "date": date,
      "time": time,
    }

# ##
# return exception msg and stacktrace
# ##
proc serverError*: string =
  let exp = getCurrentException()
  let stackTrace = exp.getStackTrace()
  result = $exp.name & ": " & exp.msg & "\n" & stackTrace