# Architecture

`main.lua` registers the debugger's event frame, performs periodic sampling, accesses `SwingBarMidnightDB` when available, and registers `/swingdebug`. `log.lua` initializes and bounds `SwingBarMidnightDebuggerDB` and exposes logging/clear operations through the shared namespace. `ui.lua` creates the main debug window and copy surface.

This addon has a runtime relationship with `SwingBarMidnight` but no TOC `Dependencies` or `OptionalDeps` declaration. It can start independently; samples that require the main addon's database are conditional on that global table being present.
