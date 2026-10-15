// scriptkid.js — Mythic scriptkid agent, JScript dialect.
// Status: SCAFFOLD. Networking loop and per-command handlers are TODO.
// Scope: see docs/minimal-agent-feature-set.md "JScript / VBScript scope".
// Build pipeline substitutes the __UPPER__ tokens at render time.

var AGENT = {
    uuid: "__UUID__",
    callback_host: "__CALLBACK_HOST__",
    callback_port: "__CALLBACK_PORT__",
    get_uri: "__GET_URI__",
    post_uri: "__POST_URI__",
    callback_interval: parseInt("__CALLBACK_INTERVAL__", 10),
    callback_jitter: parseInt("__CALLBACK_JITTER__", 10),
    profile_headers: ("__PROFILE_HEADERS__"),
    jobs: {}
};

// Per-command handler stubs. Each takes a parsed task object and must return
// a result object { user_output: string, completed: bool } or throw.
// Implement these one at a time, ticking the matching row in
// docs/minimal-agent-feature-set.md as each lands.
var HANDLERS = {
    "help": function (task) { throw new Error("TODO: help"); },
    "exit": function (task) {
        try { WScript.Quit(0); } catch (e) { /* host without WScript */ }
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
    if (!h) { return { user_output: "unknown command: " + task.command, completed: true }; }
    return h(task);
}

// Entry point. The callback loop (checkin, task fetch, result post, sleep)
// is intentionally left unimplemented in this scaffold — see
// docs/ai-agent-authoring-guide.md section 4 for the contract to fulfil.
function main() {
    // TODO: implement checkin + task loop against AGENT.get_uri / AGENT.post_uri
}

main();
