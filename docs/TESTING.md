# Dasher Ascent 0.7 verification

Final local release verified on 8 October 2026. Source and place hashes are recorded in verification-results.json. Publication is left to the user.

## Native gameplay

Artifact native07-1791378412 completed all three towers on the first attempt: Helix 125.16s, Canopy 112.15s, Reactor 112.57s. All 192 P001-P064 landings, three crown approaches and exact finish-pad contacts were recorded. The driver used ordinary Humanoid movement and server-approved Updraft, with no teleports or movement exemptions. Non-script geometry is identical to production; intermission18/countdown8/race420/results10 timings match production.

Zero unexpected resets, zero movement corrections and zero detected game-script runtime errors occurred during the completed routes. Automatic speed/flight policing was removed at the user's request; this is not evidence of movement-exploit prevention. All 24 required climbs and one extra approved Updraft return passed. The Helix probe covered four repeated ordinary jumps and a controlled P020-to-P019 fall followed by an Updraft return. An alternate branch, results and next-round transitions were observed.

At each summit the driver waited on CrownDeck without finishing, then walked onto FinishPad. No premature-finish exception is accepted.

Studio later reserialized the named QA file. Verification uses the byte-identical original ASCENT07_LOCAL_TEST_ONLY.rbxlx, SHA-256 cfb29d8b0238736a27a2b643b548283c8060d179d936cdfd4d1c44bab21381a6, matching the original logged artifact identity. Saved Desktop checkpoint geometry and scripts were independently compared; all generated objects and properties are preserved. Original Desktop bytes are retained during final replacement.

Earlier Studio settings evidence recorded 100 ms inbound/outbound delay. Those settings were still present on resumption and were restored to 0/0 before the separate UI session. The earlier settings record identifies a different artifact, so the final traversal is not presented as an independently verified network-simulation run.

## Camera, countdown and hold UI

Rendered camera samples from all three maps passed near-route framing, clear lens and clear sightline checks. Independent oriented-box geometry checks include nonquery decoration and all ten spawn handoffs per map. Enclosing walls/ribs/rims were removed; route surfaces, hazards and fall catches remain.

4 complete 3/2/1/GO sequences passed timing checks in the production-timing gameplay session. During 3/2/1 the camera was Custom, cinematic false and avatar anchored; GO followed release.

Separate artifact hold-ui07-1791451292 passed the rendered hold UI check while Studio retained focus throughout the attempt. It embeds the same production source/geometry plus a client observer and temporary-profile Studio mode. That mode uses accelerated 2/1/12/2 phase timings: this separate session proves hold interaction during Racing, not production countdown/camera timing.

The actual shipped hold helper canceled on early release and menu opening, displayed progress, and generated exactly one ManualRestart during a full hold, with no repeat while still held. Fill samples were 32% before short release, 35% before menu cancellation and 50% at full-hold midpoint. Zero game-script runtime errors were detected. This intentional restart is separate from the zero unexpected traversal resets.

The failed hold smoke at the end of the older traversal remains diagnostic history. It was not counted as passing. The separate successful hold session is bound by its own artifact hash, complete source fingerprint and exact log/session boundaries.

## Source-bound regressions

- 41 movement/lifecycle traces, including ordinary movement without automatic correction and bounded non-finite recovery.
- 91 finish/lifecycle checks, including ten simulated entrants, ranks, reward deduplication and grounded finish contact.
- 30 server moving-support checks, 35 client carry checks and 18 readiness checks.
- 86 clock checks covering delayed/reordered snapshots and varied render rates.
- 52 profile/rule checks covering migration, storage failure and Updraft recharge.
- Seven shuttle-corner trajectory replays with 0.1-0.5 s delayed rider poses.
- 78 hold-reset input/state checks and 68 dialogue/lifecycle checks.
- 54 camera planner/obstruction checks, including rotated and nonquery decoration.
- Six geometry groups covering 339 primary/alternate avatar corridors.
- All ten embedded production scripts/modules match the shipped source files.

Full source hashes and evidence are in verification-results.json. Failed or interrupted sessions do not fill gaps in the passing sessions.

## Limits

Local Studio evidence only. No real ten-client load test, physical mobile/controller test, unusual avatar-bundle test, live persistence test or purchase-receipt test was performed. Native hold UI calls the shipped helper; actual hardware wiring is covered by extracted-source tests. Traversal proves a possible route, not error-free behavior for every movement or network condition. Human playtesting remains useful for difficulty, enjoyment and additional edge cases. Robux purchases remain disabled.

## GitHub refresh — 8 October 2026

The refresh rebuilt the production place byte-for-byte, verified all ten embedded sources and reran the [portable regression suites](../tests/README.md): 560 deterministic checks/replays, six geometry groups and the separate camera geometry audit passed. The original native route and hold-UI artifacts were independently revalidated against current source and geometry. No new native Studio session was run during this refresh. [PUBLICATION-VERIFICATION.json](PUBLICATION-VERIFICATION.json) records the refresh checks separately from the archived gameplay evidence above.
