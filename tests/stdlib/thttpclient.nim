discard """
  cmd: "nim c --threads:on -d:ssl $file"
  exitcode: 0
  output: "OK"
  disabled: "travis"
  disabled: "appveyor"
  disabled: "azure"
"""

import strutils
from net import TimeoutError

import nativesockets, os, httpclient, asyncdispatch

const manualTests = false

proc asyncTest() {.async.} =
  var client = newAsyncHttpClient()
  var resp = await client.request("http://example.com/")
  doAssert(resp.code.is2xx)
  var body = await resp.body
  body = await resp.body # Test caching
  doAssert("<title>Example Domain</title>" in body)

  resp = await client.request("http://example.com/404")
  doAssert(resp.code.is4xx)
  doAssert(resp.code == Http404)
  doAssert(resp.status == Http404)

  resp = await client.request("https://google.com/")
  doAssert(resp.code.is2xx or resp.code.is3xx)

  # getContent
  try:
    discard await client.getContent("https://google.com/404")
    doAssert(false, "HttpRequestError should have been raised")
  except HttpRequestError:
    discard
  except:
    doAssert(false, "HttpRequestError should have been raised")


  when false:
    # w3.org now blocks travis, so disabled:
    # Multipart test.
    var data = newMultipartData()
    data["output"] = "soap12"
    data["uploaded_file"] = ("test.html", "text/html",
      "<html><head></head><body><p>test</p></body></html>")
    resp = await client.post("http://validator.w3.org/check", multipart=data)
    doAssert(resp.code.is2xx)

  # onProgressChanged
  when manualTests:
    proc onProgressChanged(total, progress, speed: BiggestInt) {.async.} =
      echo("Downloaded ", progress, " of ", total)
      echo("Current rate: ", speed div 1000, "kb/s")
    client.onProgressChanged = onProgressChanged
    await client.downloadFile("http://speedtest-ams2.digitalocean.com/100mb.test",
                              "100mb.test")

  client.close()

  # Proxy test
  #when manualTests:
  #  client = newAsyncHttpClient(proxy = newProxy("http://51.254.106.76:80/"))
  #  var resp = await client.request("https://github.com")
  #  echo resp

proc syncTest() =
  var client = newHttpClient()
  var resp = client.request("http://example.com/")
  doAssert(resp.code.is2xx)
  doAssert("<title>Example Domain</title>" in resp.body)

  resp = client.request("http://example.com/404")
  doAssert(resp.code.is4xx)
  doAssert(resp.code == Http404)
  doAssert(resp.status == Http404)

  resp = client.request("https://google.com/")
  doAssert(resp.code.is2xx or resp.code.is3xx)

  # getContent
  try:
    discard client.getContent("https://google.com/404")
    doAssert(false, "HttpRequestError should have been raised")
  except HttpRequestError:
    discard
  except:
    doAssert(false, "HttpRequestError should have been raised")

  when false:
    # w3.org now blocks travis, so disabled:
    # Multipart test.
    var data = newMultipartData()
    data["output"] = "soap12"
    data["uploaded_file"] = ("test.html", "text/html",
      "<html><head></head><body><p>test</p></body></html>")
    resp = client.post("http://validator.w3.org/check", multipart=data)
    doAssert(resp.code.is2xx)

  # onProgressChanged
  when manualTests:
    proc onProgressChanged(total, progress, speed: BiggestInt) =
      echo("Downloaded ", progress, " of ", total)
      echo("Current rate: ", speed div 1000, "kb/s")
    client.onProgressChanged = onProgressChanged
    client.downloadFile("http://speedtest-ams2.digitalocean.com/100mb.test",
                        "100mb.test")

  client.close()

  when false:
    # Disabled for now because it causes troubles with AppVeyor
    # Timeout test.
    client = newHttpClient(timeout = 1)
    try:
      resp = client.request("http://example.com/")
      doAssert false, "TimeoutError should have been raised."
    except TimeoutError:
      discard
    except:
      doAssert false, "TimeoutError should have been raised."

proc makeIPv6HttpServer(hostname: string, port: Port): AsyncFD =
  let fd = newNativeSocket(AF_INET6)
  setSockOptInt(fd, SOL_SOCKET, SO_REUSEADDR, 1)
  var aiList = getAddrInfo(hostname, port, AF_INET6)
  if bindAddr(fd, aiList.ai_addr, aiList.ai_addrlen.Socklen) < 0'i32:
    freeAddrInfo(aiList)
    raiseOSError(osLastError())
  freeAddrInfo(aiList)
  if listen(fd) != 0:
    raiseOSError(osLastError())
  setBlocking(fd, false)

  var serverFd = fd.AsyncFD
  register(serverFd)
  result = serverFd

  proc onAccept(fut: Future[AsyncFD]) {.gcsafe.} =
    if not fut.failed:
      let clientFd = fut.read()
      clientFd.send("HTTP/1.1 200 OK\r\LContent-Length: 0\r\LConnection: Closed\r\L\r\L").callback = proc() =
        clientFd.closeSocket()
      serverFd.accept().callback = onAccept
  serverFd.accept().callback = onAccept

proc ipv6Test() =
  var client = newAsyncHttpClient()
  let serverFd = makeIPv6HttpServer("::1", Port(18473))
  var resp = waitFor client.request("http://[::1]:18473/")
  doAssert(resp.status == "200 OK")
  serverFd.closeSocket()
  client.close()

syncTest()
waitFor(asyncTest())
ipv6Test()

echo "OK"
