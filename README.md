# scriptkid — Mythic 4.0 payload type (JScript + VBScript, Windows-only)

Status: **scaffold**. Mythic-side plumbing is complete and should register with the
server as-is. Agent-side code (`Payload_Type/scriptkid/scriptkid/agent_code/scriptkid.{js,vbs}`)
is a dispatcher skeleton with per-command TODO stubs.

## Scope

- Windows only (`cscript.exe` / `wscript.exe` host).
- Command set is the "JScript / VBScript scope" section of
  [`minimal-agent-feature-set.md`](https://github.com/dmcxblue/MythicSetup/blob/main/docs/minimal-agent-feature-set.md).
  Out-of-scope rows (execution of arbitrary native code, token manipulation, in-process
  .NET load, screenshot, dcsync, process injection) are tracked there.
- C2 profiles: `http`, `httpx`.
- Mythic version: `4.0.0` and later (uses the 4.0 repo layout: `config.json` +
  `agent_capabilities.json` + `Payload_Type/<name>/` + `agent_icons/<name>.svg`).

## Install

```
./mythic-cli install github https://github.com/dmcxblue/scriptkid
```

Or let `setup-mythic.sh` do it on a fresh install — it's in the default `AGENTS` list.

## Layout

```
scriptkid/
├── config.json
├── agent_capabilities.json
├── agent_icons/scriptkid.svg
└── Payload_Type/
    └── scriptkid/
        ├── Dockerfile              # FROM itsafeaturemythic/mythic_python_base:latest
        ├── main.py                 # start_and_run_forever() boilerplate
        └── scriptkid/
            ├── __init__.py
            ├── agent_code/
            │   ├── scriptkid.js    # JScript template (SCAFFOLD)
            │   └── scriptkid.vbs   # VBScript template (SCAFFOLD)
            └── mythic/
                ├── __init__.py
                └── agent_functions/
                    ├── scriptkid.svg
                    ├── builder.py  # renders either template per build parameter
                    ├── help.py / pwd.py / ls.py / mkdir.py / mv.py / cat.py
                    ├── upload.py / download.py
                    ├── ps.py / kill.py / jobs.py / jobkill.py
                    ├── env.py / getprivs.py
                    ├── process_spawn.py
                    └── kerberoast.py
```

## Build parameters

| Name | Values | Default |
|------|--------|---------|
| `language` | `jscript`, `vbscript` | `jscript` |
| `callback_jitter` | 0-100 | `20` |

## Next steps

1. Verify the payload type appears in the Mythic 4.0 UI payload picker.
2. Fill in the callback loop and per-command handlers in
   `agent_code/scriptkid.{js,vbs}`; tick each row in `minimal-agent-feature-set.md`.
