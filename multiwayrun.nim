import os, osproc, strutils

proc main() =
  if paramCount() != 1:
    quit """Usage: $# <shell command>""" % [getAppFilename()]

  let exe = paramStr 1
  echo "Running ", exe, " with execShellCmd"
  echo "Error code: ", execShellCmd exe
  echo "Running ", exe, " with execCmdEx"
  echo execCmdEx exe

when isMainModule: main()
