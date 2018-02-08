#[
Copyright (c) 2017, Euan T.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of nim-project-template nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]#

import base64

when defined(openbsd):
  proc arc4random(): uint32 {.importc: "arc4random", header: "<stdlib.h>".}

  proc arc4random_buf(buf: pointer, nbytes: csize) {.importc: "arc4random_buf", header: "<stdlib.h>".}

  proc arc4random_uniform(upperBound: uint32): uint32 {.importc: "arc4random_uniform", header: "<stdlib.h>".}

  proc getRandomBytes*(buf: pointer, len: int) =
    ## Fill a buffer `buff` with `len` random bytes.
    arc4random_buf(buf, len)

  proc getRandom*(): uint32 =
    ## Generate a random value in the range `0` to `0xffffffff`.
    result = arc4random()

  proc getRandom*(upperBound: uint32): uint32 =
    ## Generate a random value in the range `0` to `upperBound`.
    ##
    ## The implementation on most platforms is derived from here: http://www.azillionmonkeys.com/qed/random.html
    ##
    ## On OpenBSD this simply calls `arc4random_uniform`.
    result = arc4random_uniform(upperBound)

  proc closeRandom*() = discard
    ## Close the source of randomness.
    ##
    ## On systems such as OpenBSD, Windows and Linux (using `getrandom()`), this does nothing.
    ## On other Posix systems, it releases any resources associated with the generation of random numbers.
elif defined(windows):
  import os

  proc RtlGenRandom(RandomBuffer: pointer, RandomBufferLength: uint64): bool {.cdecl, dynlib: "Advapi32.dll", importc: "SystemFunction036".}

  proc getRandomBytes*(buf: pointer, len: int) =
    ## Fill a buffer `buff` with `len` random bytes.
    if not RtlGenRandom(buf, uint64(len)):
      raiseOsError(osLastError())

  proc getRandom*(): uint32 =
    ## Generate a random value in the range `0` to `0xffffffff`.
    if not RtlGenRandom(addr result, uint64(sizeof(uint32))):
      raiseOsError(osLastError())

  proc closeRandom*() = discard
    ## Close the source of randomness.
    ##
    ## On systems such as OpenBSD, Windows and Linux (using `getrandom()`), this does nothing.
    ## On other Posix systems, it releases any resources associated with the generation of random numbers.
elif defined(posix):
  import posix, os

  type
    RandomSource = object
      when defined(linux):
        isGetRandomAvailable: bool
      urandomHandle: cint

  var
    isRandomSourceInitialised: bool = false
    randomSource: RandomSource
    S_IFMT {.importc: "S_IFMT", header: "<sys/stat.h>".}: cint
    S_IFCHR {.importc: "S_IFCHR", header: "<sys/stat.h>".}: cint

  when defined(linux):
    var
      SYS_getrandom {.importc: "SYS_getrandom", header: "<syscall.h>".}: clong

    proc syscall(number: clong, buf: pointer, buflen: csize, flags: cint): clong {.importc: "syscall", header: "<unistd.h>".}

    proc safeSyscall(buffer: pointer, size: int) =
      var
        readNumberBytes: int
        mutBuf: pointer = buffer
        mutSize = size
        lastError: OSErrorCode

      while mutSize > 0:
        readNumberBytes = syscall(SYS_getrandom, mutBuf, mutSize, 0)
        lastError = osLastError()
        while readNumberBytes < 0 and (lastError == OSErrorCode(EINTR) or lastError == OSErrorCode(EAGAIN)):
          readNumberBytes = syscall(SYS_getrandom, mutBuf, mutSize, 0)
          lastError = osLastError()

        if readNumberBytes < 0:
          raiseOsError(osLastError())

        if readNumberBytes == 0:
          break

        dec(mutSize, readNumberBytes)

        if mutSize == 0:
          break

        mutBuf = cast[pointer](cast[int](mutBuf) + readNumberBytes)

  proc checkIsCharacterDevice(statBuffer: Stat): bool =
    ## Check if a device is a character device using the structure initialised by `fstat`.
    result = (int(statBuffer.st_mode) and S_IFMT) == S_IFCHR

  proc openDevUrandom(): cint =
    ## Open the /dev/urandom file, making sure it is a character device.
    result = posix.open("/dev/urandom", O_RDONLY)
    if result == -1:
      isRandomSourceInitialised = false
      raiseOsError(osLastError())

    let existingFcntl = fcntl(result, F_GETFD)
    if existingFcntl == -1:
      isRandomSourceInitialised = false
      discard posix.close(result)
      raiseOsError(osLastError())

    if fcntl(result, F_SETFD, existingFcntl or FD_CLOEXEC) == -1:
      isRandomSourceInitialised = false
      discard posix.close(result)
      raiseOsError(osLastError())

    var statBuffer: Stat
    if fstat(result, statBuffer) == -1:
      isRandomSourceInitialised = false
      discard posix.close(result)
      raiseOsError(osLastError())

    if not checkIsCharacterDevice(statBuffer):
      isRandomSourceInitialised = false
      discard posix.close(result)
      raise newException(OSError, "/dev/urandom is not a valid character device")

  proc initRandomSource(): RandomSource =
    # Initialise the source of randomness.
    when defined(linux):
      result = RandomSource(isGetRandomAvailable: true)

      var data: uint8 = 0'u8
      if syscall(SYS_getrandom, addr data, 1, 0) == -1:
        let error = int32(osLastError())
        if error in {ENOSYS, EPERM}:
          # The getrandom syscall is not available, so open the /dev/urandom file
          result.isGetRandomAvailable = false
          result.urandomHandle = openDevUrandom()
        else:
          raiseOsError(osLastError())
    else:
      result = RandomSource(urandomHandle: openDevUrandom())

  proc getRandomSource(): RandomSource =
    ## Get the random source to use in order to get random data.
    if not isRandomSourceInitialised:
      randomSource = initRandomSource()
      isRandomSourceInitialised = true

    result = randomSource

  proc safeRead(fileHandle: cint, buffer: pointer, size: int) =
    var
      readNumberBytes: int
      mutBuf: pointer = buffer
      mutSize = size
      lastError: OSErrorCode

    while mutSize > 0:
      readNumberBytes = posix.read(fileHandle, mutBuf, mutSize)
      lastError = osLastError()
      while readNumberBytes < 0 and (lastError == OSErrorCode(EINTR) or lastError == OSErrorCode(EAGAIN)):
        readNumberBytes = posix.read(fileHandle, mutBuf, mutSize)
        lastError = osLastError()

      if readNumberBytes < 0:
        raiseOsError(osLastError())

      if readNumberBytes == 0:
        break

      dec(mutSize, readNumberBytes)

      if mutSize == 0:
        break

      mutBuf = cast[pointer](cast[int](mutBuf) + readNumberBytes)

  proc getRandomBytes*(buf: pointer, len: int) =
    ## Fill a buffer `buff` with `len` random bytes.
    let source = getRandomSource()

    when defined(linux):
      if source.isGetRandomAvailable:
        ## Using a fairly recent Linux kernel with the `getrandom` syscall, so use that.
        safeSyscall(buf, len)
        return

    safeRead(source.urandomHandle, buf, len)

  proc getRandom*(): uint32 =
    ## Generate a random value in the range `0` to `0xffffffff`.
    let source = getRandomSource()

    when defined(linux):
      if source.isGetRandomAvailable:
        ## Using a fairly recent Linux kernel with the `getrandom` syscall, so use that.
        safeSyscall(addr result, sizeof(uint32))
        return result

    safeRead(source.urandomHandle, addr result, sizeof(uint32))

  proc closeRandom*() =
    ## Close the source of randomness.
    ##
    ## On systems such as OpenBSD, Windows and Linux (using `getrandom()`), this does nothing.
    ## On other Posix systems, it releases any resources associated with the generation of random numbers.
    if isRandomSourceInitialised:
      isRandomSourceInitialised = false
      when defined(linux):
        if not randomSource.isGetRandomAvailable:
          discard posix.close(randomSource.urandomHandle)
      else:
        discard posix.close(randomSource.urandomHandle)
else:
  {.error: "Unsupported platform".}

proc getRandomBytes*(len: static[int]): array[len, byte] =
  ## Generate an array of random bytes in the range 0 to 0xff of length `len`.
  getRandomBytes(addr result[0], len)

proc getRandomBytes*(len: int): seq[byte] =
  ## Generate a seq of random bytes in the range 0 to 0xff of length `len`.
  newSeq(result, len)
  getRandomBytes(addr result[0], len)

proc getRandomString*(len: static[int]): string =
  ## Create a random string with the given number of bytes.
  ##
  ## This will create an array of characters of the given `len` length, fill that using `getRandomBytes` then Base 64 encode the result.
  let buff = getRandomBytes(len)
  result = encode(buff)

proc getRandomString*(len: int): string =
  ## Create a random string with the given number of bytes.
  ##
  ## This will allocate a sequence of characters of the given `len` length, fill that using `getRandomBytes` then Base 64 encode the result.
  var buff = newSeq[char](len)
  getRandomBytes(addr buff[0], len)
  result = encode(buff)

when not defined(openbsd):
  const RandomScale = (1.0 / (1.0 + float64(0xffffffff)))

  from math import floor

  proc randBiased(x: float32): bool =
    var
      xCopy = x
      p: float64
    while true:
      p = float64(getRandom()) * RandomScale
      if p >= xcopy:
        return false

      if (p + RandomScale) <= xcopy:
        return true

      xcopy = (xcopy - p) * (1.0 + RandomScale)

  proc getRandom*(upperBound: uint32): uint32 =
    ## Generate a random value in the range `0` to `upperBound`.
    ##
    ## The implementation on most platforms is derived from here: http://www.azillionmonkeys.com/qed/random.html
    ##
    ## On OpenBSD this simply calls `arc4random_uniform`.
    let resolution: float64 = float64(upperBound) * RandomScale
    var
      x: float64 = resolution * float64(getRandom())
      lo: int = int(floor(x))
      xhi: float64 = x + resolution

    while true:
      inc(lo)
      if float64(lo) >= xhi or randBiased((float64(lo) - x) / (xhi - x)):
        return uint32(lo - 1)
      x = float64(lo)