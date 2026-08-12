# Code index

| File | Responsibility |
| --- | --- |
| `main.lua` | event registration, state sampling, `/swingdebug`, access to main-addon DB |
| `log.lua` | debugger SavedVariables, bounded log, clear operation |
| `ui.lua` | debugger and copy windows, update/toggle controls |

Primary anchors: `RegisterEventsNow`, `OverlayActiveCount`, `ns.InitLogger`, `ns.Clear`, `UI:Toggle`, and `SlashCmdList["SWINGDEBUG"]`.
