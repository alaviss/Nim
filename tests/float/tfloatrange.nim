discard """
  cmd: "nim c -d:release --rangeChecks:on $file"
  output: '''StrictPositiveRange
float
range fail expected
range fail expected
'''
"""
import math, fenv

type
  Positive = range[0.0..Inf]
  StrictPositive = range[minimumPositiveValue(float)..Inf]
  Negative32 = range[-maximumPositiveValue(float32) .. -1.0'f32]

proc myoverload(x: float) =
  echo "float"

proc myoverload(x: Positive) =
  echo "PositiveRange"

proc myoverload(x: StrictPositive) =
  echo "StrictPositiveRange"

let x = 9.0.StrictPositive
myoverload(x)
myoverload(9.0)

try:
  if not (sqrt(x) == 3.0):
    raise newException(Exception, "sqrt(x) != 3.0 (" & $sqrt(x) & ")")
except:
  echo getCurrentExceptionMsg()

var z = -10.0
try:
  myoverload(StrictPositive(z))
except:
  echo "range fail expected"
  
  
proc strictOnlyProc(x: StrictPositive): bool =
  if x > 1.0: true else: false
  
let x2 = 5.0.Positive
try:
  if not strictOnlyProc(x2):
    raise newException(Exception, "strictOnlyProc(x2)")
except:
  echo getCurrentExceptionMsg()

try:
  let x4 = 0.0.Positive
  discard strictOnlyProc(x4)
except:
  echo "range fail expected"
  
