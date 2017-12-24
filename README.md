# mofuw
> mofuw is **M**eccha hayai Asynchronous, Non-Blocking I/**O** no super **F**ast de **U**ltra minimal na **W**eb server on Nim.

### Warning
mofuw is now developping. please be careful when using.

### Featuer
- high-performance
- low used memory
- used backend is libuv, so Asynchronous I/O and Non-Blocking I/O
- my parser is implement like [picohttpparser](https://github.com/h2o/picohttpparser), so Zero-Copy, ultra fast parsing
- Easy API, create Web Application, create an extended Web server

### Todo
- Cache (memory buffer ? collab with redis ?)
- File response (will soon complete)
- routing (now support GET only, want to finish it early)
- multi-thread (this need ?)