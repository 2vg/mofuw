# mofuw 

[![Author: 2vg](https://img.shields.io/badge/mofuw-%C2%B0%CA%9A%20%C9%9E%C2%B0-green.svg)](https://github.com/2vg/mofuw)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## Build Status

#### Linux: [![Build Status](https://semaphoreci.com/api/v1/2vg/mofuw/branches/master/badge.svg)](https://semaphoreci.com/2vg/mofuw)

#### macOS: [![Build Status](https://travis-ci.org/2vg/mofuw.svg?branch=master)](https://travis-ci.org/2vg/mofuw)

#### Windows: [![Build status](https://ci.appveyor.com/api/projects/status/m6g40k0fd3m1w08t?svg=true)](https://ci.appveyor.com/project/2vg/mofuw)

> **MO**re **F**ast **U**ltra **W**eb server.

> もふぅ ꒰ᐡ - ﻌ - ᐡ꒱ ♡ @2vg

> ~~mofuw is **M**eccha hayai Asynchronous I/**O** no super **F**ast de **U**ltra minimal na **W**eb server on Nim.~~

## Warning
mofuw is now developping.

please be careful when using.

## FAQ
- Why fast ?
because using asyncdispatch, and using fast parser.

about my parser, check [mofuparser](https://github.com/2vg/mofuparser)

- Why changed using libuv to asyncdispatch ?

A. because asyncdispatch is great module than libuv.

asyncdispatch is very easy to use and excellent in handling asynchronous IO.

- dislike libuv ?

A. **No**. but, tired of memory management lel.

- Why is Windows at the bottom of build status section ?

A. because Windows is shitty.

## Require
- Nim >= 0.18.0

## Support Platforms
- Windows10 (tested on x64)
- Linux
- MacOSX

## Setup
before mofuw install, 

need Nim setup.

```shell
sh setup.sh
```

after setup, need add /bin directory path to PATH.

## Usage
see [example](https://github.com/2vg/mofuw/blob/master/example)

you want to ask how to build ? B U I L D ? hahaha, is joke ?

mofuw is non need B U I L D.

install is need only `git clone`.

of course, installed Nim >= 0.18.0.

see [setup](https://github.com/2vg/mofuw/blob/master/README.md#setup) section.

```sh
git clone https://github.com/2vg/mofuw
```

you can use "import mofuw". this only.

minimal example is this 👇

```nim
import mofuw

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
    get "/":
      mofuwResp(
        HTTP200,
        "text/plain",
        "Hello, World!"
      )

handler.mofuwRun() # default listening port: 8080
```

want serve static file ? OKOK, no problem.

can use `routesStatic` macro.

```nim
import mofuw

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  # public directory serving.
  routesStatic "public":
    get "/api/hello":
      mofuwResp(
        HTTP200,
        "text/plain",
        "Hello, World!"
      )

handler.mofuwRun()
```

W O W, super E A S Y !!!!!! AMAZING !!!!!!!

and...... hyper F A S T !!!!!!! YEAHHHHHHHHHHH.....

if you will using mofuw, you will be very surprised.

if you want to see more example, see [example](https://github.com/2vg/mofuw/tree/master/example)

## Feature
- high-performance
- low used memory
- used backend is Nim's asyncdispatch, so all is Asynchronous I/O :)
- my parser is implement like [picohttpparser](https://github.com/h2o/picohttpparser), so Zero-Copy, ultra fast parsing... yeah, fast may.
- Easy API, create Web Application, create an extended Web server
- multi-thread event-loop.

## Benchmark
see this benchmark result.

mofuw is more faster than [tokio-minihttp](https://github.com/tokio-rs/tokio-minihttp).

~~Update: changed routing match is using hash table so performance was down but a bit faster than tokio-mini yet.~~

### my server spec:

- OS: Arch Linux 4.13.8-1-ARCH
- CPU: Intel core 2Duo T7700 2.40GHz 3 Core
- MEM: 2GB

### tokio-minihttp

![tokio-minihttp.png](images/tokio-minihttp.png)

### mofuw

![mofuw.png](images/mofuw.png)

this is a benchmark result of [techempower](https://www.techempower.com/benchmarks/#section=data-r15&hw=ph&test=plaintext), but if can apply my benchmark result to this techempower's benchmark result, **👑 mofuw can aim at 1st place 👑**.

## Todo
- [x] ~~header make proc(?)~~
- [x] Cache (memory buffer ? collab with redis ?)
- [ ] delete cache with timer;
- [x] ~~File response (will soon complete)~~
- [x] ~~routing (now support GET, POST, PATCH, PUT, DELETE, OPTIONS only, want to finish it early)~~
- [x] ~~multi-thread (this need ?)~~

## Contribute
**Pull requests are welcome !!!!!**

I am looking for someone who develops mofuw together.

Especially if there are people who can speed up and refactor it is the best!

## Special Thanks
- [jester](https://github.com/dom96/jester) (using jester's pattern and utils, and study macro)

- Thanks a lot dom96, and all Nimmers !