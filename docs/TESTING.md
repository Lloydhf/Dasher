# Verification — 2026-09-16

Tested with the installed Roblox Studio 0.739 on Windows. This is a playable first release, not a claim of exhaustive QA or commercial readiness.

## Passed in Studio

- All five scripts in the isolated test place compiled with Studio's Luau compiler.
- 25 assertions passed for profile defaults, finite rewards, insufficient funds, unknown/unowned cosmetics, single debit, equip, improving records, cleanup and map structure.
- Accelerated rounds reached Skyline, Neon and Grid in order.
- A test controller drove the user's loaded avatar through **all 26 primary platforms on each map**, using real Humanoid walking/jumping and the production Dash input function. It never teleported the character or assigned velocity to pass a course.
- The server accepted all three finishes, including all eight ordered gates, and awarded 60 coins per finish. Test run times: Cloudline 30.00 s (includes intentional restarts), Afterhours 25.02 s, The Grid 23.50 s. These are automated feasibility checks, not representative player completion times.
- 25 predicted Dash actions were confirmed by the server. Main 14-stud gaps were crossed and landed on physically.
- Walking off the launch deck returned the player to the start. R/restart did the same. Both preserved the run's start timestamp and reset progress.
- The in-game trail shop was opened through the UI. Buying SOLAR reduced the test balance from 180 to 60 and equipped it.
- Cloud, night-city and classic-block scenes, the HUD and trail shop were visually inspected at an approximately 812×677 Studio viewport. Default player-list overlap and low-contrast hint text were corrected.

## Not yet verified

- Multiple simultaneous clients, real network latency, late join/leave edge cases, and the first-finisher acceleration button under live competition.
- Persistent saves in a published experience, reconnect/session-lock contention and Roblox service outages. Studio deliberately uses memory-only profiles.
- Physical mobile/gamepad input, broad device performance, unusually sized avatar packages and every optional shortcut.
- Human difficulty/fun testing. Tune from player observations rather than treating the automated timings as balance targets.

No runtime error in the game's scripts was observed during the completed tests. Studio emitted unrelated online-service/avatar-mesh warnings; these were not counted as successful game checks. Movement validation reduces common invalid movement; it is not a promise to prevent every exploit.

## Reproduce

`python tools/build.py --qa --output Dasher-QA.rbxlx` embeds the structure/economy harness and short rounds. Open that file and press Play; inspect Output for `[DASHER_QA]`.

The additional physical-play controller used during development is separate from the distributable game. The normal build contains four production scripts and no test bot, shortened rounds, artificial starting balance or QA remotes.

Before opening the experience to the public, run a small friend playtest with at least two clients and a phone, and verify save/rejoin in the published private experience.
