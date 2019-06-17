import os, osproc, strutils

proc main() =
  if paramCount() <= 0:
    quit """Usage: $# <shell command>""" % [getAppFilename()]

  let
    exe = paramStr 1
    subproc = paramCount() > 1
  echo "Running ", exe, " with execShellCmd"
  echo "Error code: ", execShellCmd exe
  echo "Running ", exe, " with execCmdEx"
  echo execCmdEx exe
  if not subproc:
    echo "Running as subproc"
    discard execShellCmd quoteShellCommand [getAppFilename(), paramStr 1, "sub"]

when isMainModule: main()
