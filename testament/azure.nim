#
#
#              The Nim Tester
#        (c) Copyright 2019 Leorize
#
#    Look at license.txt for more info.
#    All rights reserved.

import base64, json, httpclient, os

const
  ApiRuns = "/_apis/runs"
  ApiResults = ApiRuns & "/results"
  ApiVersion = "?api-version=5.0"

var
  http: HttpClient
  runId = -1

let isAzure* = existsEnv("TF_BUILD")

proc invokeRest(httpMethod: HttpMethod; api: string; body: JsonNode): Response =
  http.request getEnv("SYSTEM_TEAMFOUNDATIONCOLLECTIONURI") & "/" &
               getEnv("SYSTEM_TEAMPROJECT") & api & ApiVersion,
               httpMethod,
               $body,
               newHttpHeaders {
                 "Accept": "application/json",
                 "Authorization": "Basic " & getEnv("SYSTEM_ACCESSTOKEN").encode(newLine = ""),
                 "Content-Type": "application/json"
               }

proc init*() =
  if not isAzure:
    return
  http = newHttpClient()
  runId = invokeRest(HttpPost,
                     ApiRuns,
                     %* {
                       "automated": true,
                       "build": { "id": getEnv("BUILD_BUILDID") },
                       "buildPlatform": hostCPU,
                       "controller": "nim-testament",
                       "name": hostOS & " " & hostCPU
                     }).body.parseJson["id"].getInt(-1)

proc deinit*() =
  if not isAzure:
    return

  discard invokeRest(HttpPatch,
                     ApiRuns & "/" & $runId,
                     %* { "status": "Completed" })

proc addTestResult*(name, filename: string; durationInMs: int; errorMsg: string;
                    outcome: string) =
  if not isAzure:
    return
  discard invokeRest(HttpPost,
                     ApiResults & "/" & $runId,
                     %* [{
                       "automatedTestName": filename,
                       "durationInMs": durationInMs,
                       "errorMessage": errorMsg,
                       "outcome": outcome,
                       "testCaseTitle": name
                     }])
