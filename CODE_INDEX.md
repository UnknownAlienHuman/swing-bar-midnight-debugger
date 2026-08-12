# Code index

| File | Exact anchors |
| --- | --- |
| [`log.lua`](log.lua) | `Ensure`, `ns.InitLogger`, `ns.Log`, `ns.Clear`, `ns.Format`; owns `SwingBarMidnightDebuggerDB` |
| [`ui.lua`](ui.lua) | `UI:Init`, `UI:Toggle`, `UI:Update`, `UI:ShowCopy`; reads exported main-addon state |
| [`main.lua`](main.lua) | `OverlayActiveCount`, `RegisterEventsNow`, event-frame handler, 0.20 s sampler, `SlashCmdList["SWINGDEBUG"]` |

Only the main addon's exported state/DB is read; no files are shared at load time.
