' scriptkid.vbs - Mythic scriptkid agent, VBScript dialect.
' Status: SCAFFOLD. Networking loop and per-command handlers are TODO.
' Scope: see docs/minimal-agent-feature-set.md "JScript / VBScript scope".
' Build pipeline substitutes the __UPPER__ tokens at render time.

Option Explicit

Dim AGENT_UUID : AGENT_UUID = "__UUID__"
Dim AGENT_HOST : AGENT_HOST = "__CALLBACK_HOST__"
Dim AGENT_PORT : AGENT_PORT = "__CALLBACK_PORT__"
Dim AGENT_GET_URI  : AGENT_GET_URI  = "__GET_URI__"
Dim AGENT_POST_URI : AGENT_POST_URI = "__POST_URI__"
Dim AGENT_INTERVAL : AGENT_INTERVAL = CInt("__CALLBACK_INTERVAL__")
Dim AGENT_JITTER   : AGENT_JITTER   = CInt("__CALLBACK_JITTER__")

' Per-command handler stubs. Each takes a task dictionary and must return a
' two-element array (output_text, completed_bool) or raise an error.
' Implement one at a time, ticking the matching row in
' docs/minimal-agent-feature-set.md as each lands.
Function Dispatch(cmd, task)
    Select Case LCase(cmd)
        Case "help"          : Err.Raise 5, , "TODO: help"
        Case "pwd"           : Err.Raise 5, , "TODO: pwd"
        Case "ls"            : Err.Raise 5, , "TODO: ls"
        Case "mkdir"         : Err.Raise 5, , "TODO: mkdir"
        Case "mv"            : Err.Raise 5, , "TODO: mv"
        Case "cat"           : Err.Raise 5, , "TODO: cat"
        Case "upload"        : Err.Raise 5, , "TODO: upload"
        Case "download"      : Err.Raise 5, , "TODO: download"
        Case "ps"            : Err.Raise 5, , "TODO: ps"
        Case "kill"          : Err.Raise 5, , "TODO: kill"
        Case "jobs"          : Err.Raise 5, , "TODO: jobs"
        Case "jobkill"       : Err.Raise 5, , "TODO: jobkill"
        Case "env"           : Err.Raise 5, , "TODO: env"
        Case "getprivs"      : Err.Raise 5, , "TODO: getprivs"
        Case "process_spawn" : Err.Raise 5, , "TODO: process_spawn"
        Case "kerberoast"    : Err.Raise 5, , "TODO: kerberoast"
        Case Else            : Err.Raise 5, , "unknown command: " & cmd
    End Select
End Function

Sub Main()
    ' TODO: implement checkin + task loop against AGENT_GET_URI / AGENT_POST_URI
    ' See docs/ai-agent-authoring-guide.md section 4.
End Sub

Main
