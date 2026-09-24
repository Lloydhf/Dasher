# Server systems — Dasher 0.2

The server owns votes, race eligibility, route validation, rewards, profile changes and weekly scores. Clients cannot submit coin, XP, finish-time or leaderboard values.

## Remotes

`Action` accepts existing `Ready`, `Dash`, `Restart`, `Accelerate`, `Buy`, `Equip` actions and the following additions:

- `Vote`, string map ID: only one current vote per ready player, only during Intermission, only for one of the three offered maps. Changing a vote replaces the prior vote. Disconnecting removes the vote. The preceding map is excluded when enough maps exist. A server-side random choice resolves tied leading candidates, including a zero-vote tie.
- `Spectate`, boolean: `true` during Racing forfeits an unfinished run, resets its progress, and returns the player to the lobby. Finished racers can spectate without penalty. `false` stops spectating but cannot restore eligibility after forfeiture. All players become eligible again next round. Normal falls/deaths still restart the course, never automatically forfeit.
- `ClaimDaily`, no payload: one explicit reward per UTC date, with no streak penalty.
- `ClaimWeekly`, no payload: one explicit reward after the configured number of verified weekly finishes; weeks reset Monday 00:00 UTC.

All actions use the existing per-player token bucket and action cooldown. The server validates payload types, membership and race phase.

## State additions

- `voteOptions = {{id, name, votes}}`, `myVote`.
- `racers = {{userId, name, displayName, progress, finished}}`, `spectating`, `forfeited`. Forfeited players are excluded from racers.
- `progression = {xp, level, xpIntoLevel, xpPerLevel, xpToNext, dailyAvailable, dailyReward, weeklyProgress, weeklyTarget, weeklyClaimed, weeklyReward, weeklyKey, weeklyScore}`.
- `leaderboard = {scope, entries = {{userId, name, score}}, weekKey, status}`. Status is `loading`, `ready`, or `unavailable`. Scope is `Studio session` for isolated tests, and `Global weekly` in a published server. A finish awards 100 points/XP; first place adds 50. Coins and purchases never affect this score.

## Saved-data compatibility

The existing `DasherProfiles_v1` DataStore is retained. Schema 1 migrates to schema 2 under the same session lock. Coins and cosmetic ownership/equipment survive. Old short-course personal records move to `legacyBest`; the expanded courses start fresh `best` values using `Config.CourseVersion = 2`. XP, daily claim day, and weekly quest/score state are persisted in the same player record.

Unknown future schemas, failed loads, and active foreign session locks cannot overwrite existing data. Studio never opens live profile or ordered stores, even if Studio API access is enabled. Following a live deployment, migrate all running servers to the new version before expecting new progression everywhere; old servers correctly refuse to overwrite schema 2 records.

## Weekly leaderboard persistence

`WeeklyLeaderboard` uses `DasherWeekly_v2` ordered stores, scoped by UTC week. `ProfileStore.OnSaved` queues the exact committed weekly score; it never publishes newer unsaved in-memory changes. Queues flush every 45 seconds. Reads are throttled to at least 60 seconds. Monotonic `UpdateAsync` writes cannot replace a higher score with an older lower score. Joining requeues the saved total and repairs missed updates. Scores can take roughly two minutes to appear globally. API failures retain the previous cache and report unavailable status; pending writes retry later.

## Current boundaries

This iteration does not enable team modes, game passes, developer products, receipt processing, or paid stage skips. Monetization IDs remain zero and no purchase buttons should promise live products. Daily/weekly economy, ten cosmetic trails and regular race competition are playable without Robux. Persisted claims share the profile save pipeline: normal server saves and final session saves protect the state; an unexpected crash before a successful save can lose recent uncommitted progress.

## Validation

- Four production server Luau files compile with the Luau compiler.
- 33 standalone Luau assertions cover migration, currency/cosmetic preservation, invalid storage reads and session locks, schema protection, UTC resets, duplicate claims, XP/levels, exact committed leaderboard snapshots during concurrent in-memory updates, monotonic ordered scores, read throttling, vote replacement, majority and seeded tie behavior.
- `tools/StudioQA.server.luau` runs additional isolated tests against the actual Roblox modules and checks all five generated maps, 74 primary landings and 24 ordered gates each. It is included only in QA builds and immediately exits outside Studio.
- Live multi-server DataStore access, multiplayer spectating and publication are separate end-to-end checks; unit compilation alone does not establish these.
