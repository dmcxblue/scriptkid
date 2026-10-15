# scriptkid — Mythic payload type (JScript + VBScript, Windows-only)

Status: **scaffold**. Mythic-side plumbing is complete and should register with
the server as-is. Agent-side code (`scriptkid/agent_code/scriptkid.{js,vbs}`)
is a dispatcher skeleton with TODO stubs; implement one command at a time and
tick the matching row in [`docs/minimal-agent-feature-set.md`](../../../docs/minimal-agent-feature-set.md).

## Scope

- Windows only (`cscript.exe` / `wscript.exe` host).
- Command set is the "JScript / VBScript scope" section of
  `docs/minimal-agent-feature-set.md`. Out-of-scope rows (execution of
  arbitrary native code, token manipulation, in-process .NET load, screenshot,
  dcsync, process injection) are tracked there and are **not** backed by
  command files here.
- C2 profiles: `http`, `httpx`.

## Layout

```
scriptkid/
├── Dockerfile                 # standard Mythic Python base
├── main.py                    # start_and_run_forever() boilerplate
├── rabbitmq_config.json
└── scriptkid/
    ├── agent_code/
    │   ├── scriptkid.js       # JScript template (SCAFFOLD)
    │   └── scriptkid.vbs      # VBScript template (SCAFFOLD)
    └── mythic/
        ├── scriptkid.svg
        └── agent_functions/
            ├── builder.py     # renders either template per build parameter
            ├── help.py
            ├── pwd.py / ls.py / mkdir.py / mv.py / cat.py
            ├── upload.py / download.py
            ├── ps.py / kill.py / jobs.py / jobkill.py
            ├── env.py / getprivs.py
            ├── process_spawn.py
            └── kerberoast.py
```

## Install into Mythic

```
cd Mythic
./mythic-cli install folder InstalledServices/scriptkid/ -f
```

The `httpx` profile container must already be installed on the server; add
`httpx` to the setup script's `--profiles` list on first install, or install
it afterwards via `./mythic-cli install github <httpx-profile-repo>`.

## Build parameters

| Name | Values | Default |
|------|--------|---------|
| `language` | `jscript`, `vbscript` | `jscript` |
| `callback_jitter` | 0-100 | `20` |

## Next steps (per `docs/ai-agent-authoring-guide.md` § 5-7)

1. Install the payload type and confirm it appears in the Mythic payload picker.
2. Fill in the callback loop in `scriptkid.{js,vbs}` and verify a checkin
   against the lab's `http` listener.
3. Implement the in-scope commands one at a time; tick each row in
   `docs/minimal-agent-feature-set.md`.
