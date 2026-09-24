# Repeatable Ascent 0.5 checks

Use Python 3 and the Luau CLI. Put `luau` on `PATH`, or set `LUAU_BIN` to its executable. No Roblox account or player data is required for these checks.

Run from the repository root:

```text
python -m unittest discover -s tools -p test_route_clearance.py -v
python tests/finish-regressions.py
python tests/movement-landing-tests.py
python tests/moving-support-tests.py
python tests/client-carry-tests.py
```

The four Python harnesses extract current production functions and run deterministic Luau mocks. They cover 95 finish/lifecycle, 23 movement, 30 moving-support, 35 carry and 18 readiness/ranking checks. The client readiness fixture must match the current client functions before it runs. Generated harnesses and reports are written to the ignored `.test-output/` directory.

The three Python geometry tests cover 339 authored route transitions and two previously observed overhead collisions. These checks complement the dated native Studio evidence in [TESTING.md](../docs/TESTING.md); they do not simulate network replication, a real ten-client load, mobile hardware or human enjoyment.

These harnesses were carried forward from the game's local QA work. The GitHub refresh changes their file locations and Luau discovery only, then reruns them against the unchanged release gameplay sources.
