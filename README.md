# mofuw
> mofuw is **M**eccha hayai Asynchronous, Non-Blocking I/**O** no super **F**ast de **U**ltra minimal na **W**eb server on Nim.

### Featuer
- high-performance
- low used memory
- used backend is libuv, so Asynchronous I/O and Non-Blocking I/O
- my parser is implement like [picohttpparser](https://github.com/h2o/picohttpparser), so Zero-Copy, ultra fast parsing... yeah, fast may.
- Easy API, create Web Application, create an extended Web server
- Multi-Core support, see app.nim

### Why fast ?
because using libuv, and using fast parser.

about my parser, check [mofuparser](https://github.com/2vg/mofuparser)

but, i want to use libev... because more faster than libuv...

if i will made Asynchronous library, i will may replace libuv to libev

### Warning
mofuw is now developping.

please be careful when using.

### Require
- nim(tested nim0.17.2)

### Usage
see app.nim.

**Now support GET method only**

### Todo
- header make proc(?)
- Cache (memory buffer ? collab with redis ?)
- File response (will soon complete)
- routing (now support GET only, want to finish it early)
- ~~multi-thread (this need ?)~~