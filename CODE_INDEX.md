# SwingBarMidnight Prediction Debugger code index

| Path | Responsibility |
|---|---|
| `SwingBarMidnight_Debugger.toc` | Retail 12.1 metadata, SwingBarMidnight dependency, SavedVariables and load order |
| `log.lua` | Access-first sanitization, schema v2, bounded persistent log, clear and deterministic bounded formatting |
| `main.lua` | Whitelisted prediction snapshots, event coalescing, lifecycle and slash commands |
| `ui.lua` | On-demand snapshot/log window and bounded copy panel |
| `tests/test_safe_prediction_debugger_12_1.lua` | Regression for inaccessible keys/values, bounded retention, event coalescing and absence of overlay/aura/polling ownership |

Removed responsibilities: overlay counting, raw speed logging, periodic sampling, and obsolete anchor/suppression fields.
