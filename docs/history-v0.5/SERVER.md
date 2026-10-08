# Dasher Ascent server — 0.5

Players climb independently with one approved ability, Updraft. Player collisions are disabled. The server exposes no horizontal dash, duel, pulse, push, or player-to-player interference actions, state, or effects.

## Branch-safe progress and finish

Every newly completed sector awards `Config.StageReward` coins and `Config.StageXP` XP (3 and 25 by default). A collidable authored route BasePart carries a `CompletedStage` IntValue from 0 through 8. Real server-verified grounded contact advances the current attempt to that milestone; a jump apex or scenery contact grants nothing. A higher alternate route fills skipped milestone claims in order. Contact with the crown Finish volume after continuous movement validation and a conservative elapsed-time check finishes regardless of which exact rest platforms the player touched. This removes the 0.4 softlock when Updraft skipped an expected rest.

Finish claims are keyed by UserId for the current server round and committed before rewards. Repeated crown contact and same-round reconnect cannot award another finish. The first finisher caps remaining time at 90 seconds. All connected entrants finishing/forfeiting, no remaining racers, or timeout advances to Results and then the next vote. Up to 10 entrants receive distinct Start01–Start10 slots. If an oversized server has waiting players, those who last played longest ago receive priority next round. The published Roblox experience MaxPlayers setting should also be 10.

`ProfileStore:BeginStageRound(roundId)` creates a monotonically increasing round ledger. `RecordStage(player, roundId, stage, totalStages)` validates the token, bounds and sequence, marks the claim, and credits coins/XP in one yield-free transaction. Claims are keyed by UserId and survive manual restarts, falls, respawns and disconnect/rejoin within the same server round. Calling BeginStageRound twice with the same token cannot clear claims. The next round permits fresh rewards. Awarded balances/XP use the existing saved profile pipeline; the round ledger itself is session-local because rounds do not survive a server restart.

Stage XP contributes to player levels. It does not count as a finished map or inflate the weekly verified-finish leaderboard. Completing the tower grants the existing finish reward and XP in addition to the earned stage rewards.

Client notification: `Feedback('StageCompleted', message, {stage, coins, xp})`. State includes top-level `stageRewarded` and `altitude.rewardedStages`. These are the highest rewarded sector this round, independent of the current attempt's gate after restarting.

## Moving terrain

`CourseMotion` reads authored metadata from Course child Models:

- Shuttle: `Motion` StringValue `Shuttle`; `Travel` Vector3Value; `Period`, `Dwell`, `Phase` NumberValues. The whole anchored model follows a smooth A-to-B-and-back path with time to board at both endpoints.
- Timed step: `Motion` StringValue `Blink`; `Period`, `OnDuration`, `WarningDuration`, `Phase` NumberValues. The step remains solid during an amber warning, then becomes noncollidable and translucent, then returns. Only parts originally marked collidable become solid again; decoration never gains collision.
- Environmental spinner: Hazards child Model with `Motion='Spinner'`, `Center`, `Bar`, `AngularSpeed` and `Phase`. The server rotates the lethal Bar about Center. Hazards include direct KillFloor/edge parts and explicitly selected Spinner Bars; decorative children and Centers are not lethal.

Shuttles move through server `Model:PivotTo`. The owning client carries its own avatar by the observed support-platform displacement in PreSimulation, after verifying foot contact and a raycast to the same collidable shuttle. Jumping, upward movement, pending Updraft, reset, forfeiture or a map change cancels carrying immediately. The server never pivots a rider's character, which avoids competing with client-owned walking and jumping.

Before each terrain motion step, the server independently raycasts below each active avatar against the old terrain position. Only a verified grounded rider, with a valid vertical speed and no pending Updraft, receives an adjustment to the server's movement-accounting origin by the authored model translation. The server accepts no client-reported carrier or displacement. A separate world-position sample remains available for hazard crossings, so accounting cannot erase a real crossing. Standing near a shuttle grants no blanket movement exemption.

Native Studio rider testing is necessary to verify smoothness under client-owned character replication. The pure phase tests establish timing and reward behavior, not networked ride quality.

The server keeps at most 0.2 seconds of its own exact shuttle surface poses. If current raycasts miss during a replicated edge ride, the same foot probes may verify contact against that recent authored surface. Jumping, upward velocity, a pending Updraft, expired history and an unrelated surface reject this fallback. It does not enlarge the normal movement or flight budgets. This addresses the false reset found during the 0.5 native shuttle test.

## Movement and falls

Updraft is the only active skill. The server approves an absolute target velocity; the owning client applies the corresponding impulse once. A spent airborne charge rearms after0.12seconds of stable grounded contact independently of its3.25second cooldown; activation still requires that cooldown to have elapsed. After arming, a later jump can activate when the timer expires. Restarting does not shorten its cooldown.

Grounding uses server raycasts against collidable active-map parts and correct R6/R15 root-to-feet dimensions. The center probe falls back to eight probes inside a maximum 0.8-stud radius, because a humanoid can stand on a platform edge while its root center is outside that edge. Support must face upward, lie within 0.55 studs of actual foot height, and have observed vertical speed below 12 studs/second. Wall proximity, surfaces above the feet and distant floors cannot grant grounding. A bounded ballistic envelope and finite positive-ascent allowance reject unsupported climbing/hovering while allowing legitimate long falls. Walking has its own bounded movement budget; only verified terrain displacement is removed from this budget.

The complete movement check runs every Racing Heartbeat, including grounding, rather than sampling landings at 0.08-second intervals. This preserves brief contact before a queued jump without introducing a separate unvalidated grounding path or enlarging the flight allowance. Client state broadcasts remain throttled to four per second.

Falling onto a lower platform continues the same attempt. Current altitude decreases while peak altitude and previously cleared gates remain recorded. Bottom void, actual hazard contact, leaving bounds, manual restart, death or invalid movement restart the attempt. The race clock continues and stage claims stay consumed.

## Remaining protocol

Actions: Ready, Updraft, Restart, Accelerate, Vote, Spectate, Buy, Equip, ClaimDaily, ClaimWeekly. Server actions remain type-checked and rate-limited. Exact boolean `Spectate(false)` retains the immediate, idempotent exit path; stopping the camera never restores a forfeited run.

`Feedback('Updraft', '', {at, velocity})` is the sole ability impulse approval. `SkillFX('Updraft', {userId, position, at})` is the sole ability effect. `abilities` includes `updraftAt`, `updraftReady`, `updraftAirUsed`, `updraftArmed` and the absolute server timestamp `updraftReadyAt`. The client derives the timer locally but the server validates every activation. Round state adds `finalSprint`, `roundEndReason` and `raceCapacity`. Altitude, spectators, votes, cosmetics, daily/weekly progression and weekly leaderboard contracts otherwise remain compatible.

## Persistence and migration

`CourseVersion=5` gives the harder towers new best times while preserving coins, XP, cosmetic ownership/equipment and archived earlier records. Existing profile session locks, unknown-schema protection, failed-read safeguards and Studio memory isolation are retained. Weekly ordered scores still publish only exact successfully saved finish-score snapshots, with batched writes and throttled reads. Real-money products are not enabled.

## Validation

`work/ascent05-qa/finish-regressions.py` executes the actual finish, entrant, validated-contact tail and round-loop functions with deterministic service mocks:95checks cover branch progress, crown finish, duplicate/rejoin protection,10-racer capacity/ranks, first-finish sprint, timeout, departure, forfeits and Results→next-round cycling. `server-tests.py` runs52profile/rule checks and compiles all six server modules. `movement-landing-tests.py` runs23checks against the actual teleport, validation prefix and ground-recharge functions. These results are logic regressions; they do not establish native10-client performance, physical avatar traversal, or live persistence.

Official references: [moving objects](https://create.roblox.com/docs/tutorials/use-case-tutorials/physics/create-moving-objects), [Model/PivotTo](https://create.roblox.com/docs/reference/engine/classes/PVInstance), [network ownership security](https://create.roblox.com/docs/scripting/security/network-ownership).
