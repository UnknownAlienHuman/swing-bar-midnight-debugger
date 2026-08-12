# SwingBarMidnight Debugger

Diagnostic companion for `SwingBarMidnight`, focused on glow anchoring and attack-speed observation. It samples runtime state, records a bounded SavedVariables log, and exposes a debug/copy UI.

**Version:** 0.1.7
**Interface:** 120000
**SavedVariables:** `SwingBarMidnightDebuggerDB`

## Install

Copy both `SwingBarMidnight` and `SwingBarMidnight_Debugger` to `World of Warcraft/_retail_/Interface/AddOns/`, enable them, and reload the UI. The debugger reads the main addon's `SwingBarMidnightDB` when it samples configuration; it is therefore intended to run beside the main addon.

## Use

Use `/swingdebug` to toggle the debugger UI. The UI exposes log viewing, copying, and clearing. No runtime SavedVariables data is committed to this repository; `SwingBarMidnightDebuggerDB` is created only in the game client.

## Current development status

No specific unfinished implementation item was found. The outstanding work is an in-game companion test: load both addons, exercise combat/recovery event registration, inspect sampling output, and verify the copy/clear controls.

## License

Licensed under the [MIT License](LICENSE). Bundled third-party components remain under their own notices.
