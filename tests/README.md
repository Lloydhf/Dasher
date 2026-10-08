# Repeatable Ascent 0.7 checks

Use Python 3 and the Luau CLI. Put `luau` and `luau-compile` on PATH, or set `LUAU_BIN` and `LUAU_COMPILE_BIN` to their executables. Run from the repository root:

```text
python -m unittest discover -s tools -p test_route_clearance.py -v
python tests/movement-regressions.py
python tests/finish-regressions.py
python tests/moving-support-tests.py
python tests/client-carry-tests.py
python tests/clock-regressions.py
python tests/server-tests.py
python tests/shuttle-latency-replay.py
python tests/reset_hold_tests.py
python tests/client_dialogue_tests.py
python tests/camera-tests.py
python tests/camera-geometry-validation.py
```

The source-bound suites cover **560 deterministic checks/replays**: movement 41, finish/lifecycle 91, moving support 30, carry 35, readiness 18, clock 86, profile/rules 52, delayed-shuttle poses 7, reset hold 78, dialogue 68 and camera 54. They extract current production functions or load the shipped modules. Fixtures that copy client helpers must match the current source before execution.

The six geometry tests cover 339 authored primary/alternate corridors, with a separate oriented-box audit of camera paths and spawn handoffs. Generated harnesses and reports go into ignored `.test-output/`.

These are the original 0.7 QA harnesses with portable locations and executable discovery. They do not simulate a real ten-client server, physical mobile/controller hardware, live persistence or player enjoyment. [TESTING.md](../docs/TESTING.md) records the separate native Studio evidence and limits.
