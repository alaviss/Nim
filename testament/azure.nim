#
#
#              The Nim Tester
#        (c) Copyright 2019 Leorize
#
#    Look at license.txt for more info.
#    All rights reserved.

import base64, json, httpclient, os, strutils

const
  ApiRuns = "/_apis/test/runs"
  ApiVersion = "?api-version=5.0"

var
  http: HttpClient
  runId = -1

template apiResults: untyped =
  ApiRuns & "/" & $runId & "/results"

let isAzure* = existsEnv("TF_BUILD")

proc getAzureEnv(env: string): string {.inline.} =
  # Conversion rule at:
  # https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables#set-variables-in-pipeline
  env.toUpperAscii().replace('.', '_').getEnv

proc invokeRest(httpMethod: HttpMethod; api: string; body: JsonNode): Response =
  result = http.request(getAzureEnv("System.TeamFoundationCollectionUri") &
                        getAzureEnv("System.TeamProjectId") & api & ApiVersion,
                        httpMethod,
                        $body,
                        newHttpHeaders {
                          "Accept": "application/json",
                          "Authorization": "Basic " & encode(':' & getAzureEnv("System.AccessToken"), newLine = ""),
                          "Content-Type": "application/json"
                        })
  if result.code != Http200:
    raise newException(HttpRequestError, "Server returned: " & result.body)

proc init*(rid = -1) =
  if not isAzure:
    return
  http = newHttpClient()
  if rid < 0:
    runId = invokeRest(HttpPost,
                       ApiRuns,
                       %* {
                         "automated": true,
                         "build": { "id": getAzureEnv("Build.BuildId") },
                         "buildPlatform": hostCPU,
                         "controller": "nim-testament",
                         "name": hostOS & " " & hostCPU
                       }).body.parseJson["id"].getInt(-1)
    echo "got run id: ", runId
  else:
    runId = rid

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
  let send = %* [{
                  "automatedTestName": filename,
                  "durationInMs": durationInMs,
                  "errorMessage": errorMsg,
                  "outcome": outcome,
                  "testCaseTitle": name
                }]
  let resp = invokeRest(HttpPost,
                        apiResults,
                        send)
  echo resp.body.parseJson

proc getRunId*(): int = runId
