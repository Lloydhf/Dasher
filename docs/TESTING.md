# Dasher 0.2 verification — 17 September 2026

## Executed

- All six production Luau sources compile with the official Luau compiler.
- 34 release checks cover embedded-source parity, unique instance references, five map contracts, 24 gates and 74 primary platforms per map, disabled commerce, and absence of QA code in the release.
- 33 standalone server assertions cover schema migration, session locking, failed reads, duplicate claims, UTC rollover, concurrent-save snapshots, ordered ranking updates and voting.
- Roblox Studio ran 551 structure/progression/voting assertions successfully.
- A Studio client physically traversed all five main routes using normal Humanoid movement and ordinary jumps. No teleports, health edits or server bypasses were used by the traversal bot. All five finishes were verified and rewarded by the normal server code.

| Route | Verified time | Coins | XP |
| --- | ---: | ---: | ---: |
| Cloudline | 78.80 s | 20 | 150 |
| The Grid | 77.00 s | 20 | 150 |
| Foundry | 72.70 s | 20 | 150 |
| Zenith | 72.90 s | 20 | 150 |
| Afterhours | 73.88 s | 20 | 150 |

These are automated experienced-route timings, not an estimate for first-time players. Cloudline includes deliberate fall and manual reset checks. Both reset progress while retaining the original race clock. A repeated dash attempt was blocked during cooldown.

Menu, shop and quest presentation were inspected in Studio. Claiming the daily reward through the actual GUI raised the test balance by 25. The normal race HUD leaves most of the viewport clear; voluntarily opened menus and voting occupy more space. Physical phones/controllers have not been tested.

## Multiplayer integration

Two Studio clients and a local server were used to exercise spectating, forfeiture, menus and optional dash forks. The first run found that an immediate spectate exit could be dropped by the action throttle. The server exit path was corrected, eight targeted regression assertions passed, and the two-client rerun passed all 16 integration assertions. These include immediate exit, correct camera subject, no forfeiture bypass, one daily grant, all ten shop entries, menu closure, results camera recovery and eligibility in the next round. Four optional dash forks were physically traversed in Zenith; the normal server verified the finish in 68.43 seconds. The same geometry pattern is used by the other maps; their optional forks were checked geometrically but not all individually traversed.

## Live limitations

Studio deliberately stores temporary data, including the weekly board. Real Roblox data-store migration, cross-server ranking updates, reconnect behavior and live network/device performance still need a controlled published test. No Robux products are enabled and no payment was tested. Team races and seasonal releases are future iterations.

Player testing should cover early difficulty, whether a fall near the end feels fair, voluntary replay, motion comfort, touch controls, slow devices and simultaneous finish/disconnect cases. No retention or revenue improvement is claimed from these local tests.

## Isolation

Disposable test places live outside the release directory and all bot/test code is guarded by IsStudio. The normal place excludes StudioQA and traversal appendages. Do not publish a file named QA or LOCAL_TEST_ONLY. Open and publish the release Dasher.rbxlx only after reviewing it.

Prior v0.1 documents are archived under history-v0.1 and are not evidence for this version.
