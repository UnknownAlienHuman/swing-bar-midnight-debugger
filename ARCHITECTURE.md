# Architecture

The TOC loads [`log.lua`](log.lua) -> [`ui.lua`](ui.lua) -> [`main.lua`](main.lua). `log.lua` owns the bounded `SwingBarMidnightDebuggerDB`; `ui.lua` owns the hidden-on-load DIALOG/copy frames; `main.lua` owns event registration, `/swingdebug`, and the 0.20 s state sampler.

The companion relationship is one-way and conditional: `main.lua` reads `_G.SwingBarMidnightState` and `_G.SwingBarMidnightDB` when present. The debugger can load independently and never supplies runtime services to `SwingBarMidnight`.

The direct read anchors are `ui.lua:131` (`SwingBarMidnightState`) and `main.lua:89`/`main.lua:92` (`SwingBarMidnightState`/`SwingBarMidnightDB`); missing globals are expected and must remain non-fatal.
