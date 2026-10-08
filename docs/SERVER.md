# Dasher Ascent server — 0.7

## Synchronized phase timing

RoundClock stores absolute Workspace:GetServerTimeNow deadlines. Countdown starts before addEntrant sends its first snapshot, eliminating the stale zero-second enrollment packet. waitPhase preserves that deadline while enrollment completes. Snapshots include phaseStartedAt, phaseEndsAt, clockRevision and monotonic stateSequence.

First-finisher caps and acceleration update the same deadline while preserving remaining game seconds. Intermission, Countdown and Results use rate 1. Server-side teleports release racers before announcing Racing. Current verification scope and native timing evidence are recorded in TESTING.md.

Players climb independently with one approved ability, Updraft. Player collisions are disabled. The server exposes no horizontal dash, duel, pulse, push, or player-to-player interference actions, state, or effects.

## Branch-safe progress and finish

Every newly completed sector awards `Config.StageReward` coins and `Config.StageXP` XP (3 and 25 by default). A collidable authored route BasePart carries a `CompletedStage` IntValue from 0 through 8. Real server-verified grounded contact advances the current attempt to that milestone; a jump apex or scenery contact grants nothing. A higher alternate route fills skipped milestone claims in order. Progress depends on authored ground contact and reward eligibility; movement-speed estimates do not suppress it.

The final route landing is an approach apron, not the finish. A player must stand on the collidable `FinishPad` with their root centre inside the exact local bounds of `Finish`. The sensor has no avatar-radius padding and does not sweep between previous/current positions. Passing below, above or beside the pad, or jumping through its prism without landing, cannot finish. After this contact and a conservative elapsed-time check, a run can finish regardless of which exact sector rests the player touched. An implausibly early contact grants nothing and leaves the attempt running; it does not reset the player. `FinishPad` must remain a descendant of the active map and align with the visible marked goal.

Finish claims are keyed by UserId for the current server round and committed before rewards. Repeated crown contact and same-round reconnect cannot award another finish. The first finisher caps remaining time at90seconds. All connected entrants finishing/forfeiting, no remaining racers, or timeout advances to Results and then the next vote. Up to10 entrants receive distinct Start01–Start10 slots. If an oversized server has waiting players, those who last played longest ago receive priority next round. The published Roblox experience MaxPlayers setting should also be10.

`ProfileStore:BeginStageRound(roundId)` creates a monotonically increasing round ledger. `RecordStage(player, roundId, stage, totalStages)` validates the token, bounds and sequence, marks the claim, and credits coins/XP in one yield-free transaction. Claims are keyed by UserId and survive manual restarts, falls, respawns and disconnect/rejoin within the same server round. Calling BeginStageRound twice with the same token cannot clear claims. The next round permits fresh rewards. Awarded balances/XP use the existing saved profile pipeline; the round ledger itself is session-local because rounds do not survive a server restart.

Stage XP contributes to player levels. It does not count as a finished map or inflate the weekly verified-finish leaderboard. Completing the tower grants the existing finish reward and XP in addition to the earned stage rewards.

Client notification: `Feedback('StageCompleted', message, {stage, coins, xp})`. State includes top-level `stageRewarded` and `altitude.rewardedStages`. These are the highest rewarded sector this round, independent of the current attempt's gate after restarting.

## Moving terrain

`CourseMotion` reads authored metadata from Course child Models:

- Shuttle: `Motion` StringValue `Shuttle`; `Travel` Vector3Value; `Period`, `Dwell`, `Phase` NumberValues. The whole anchored model follows a smooth A-to-B-and-back path with time to board at both endpoints.
- Timed step: `Motion` StringValue `Blink`; `Period`, `OnDuration`, `WarningDuration`, `Phase` NumberValues. The step remains solid during an amber warning, then becomes noncollidable and translucent, then returns. Only parts originally marked collidable become solid again; decoration never gains collision.
- Environmental spinner: Hazards child Model with `Motion='Spinner'`, `Center`, `Bar`, `AngularSpeed` and `Phase`. The server rotates the lethal Bar about Center. Hazards include direct KillFloor/edge parts and explicitly selected Spinner Bars; decorative children and Centers are not lethal.

Shuttles move through server `Model:PivotTo`. The owning client carries its own avatar by the observed support-platform displacement in PreSimulation, after verifying foot contact and a raycast to the same collidable shuttle. Jumping, upward movement, pending Updraft, reset, forfeiture or a map change cancels carrying immediately. The server never pivots a rider's character, which avoids competing with client-owned walking and jumping.

The server advances the authored terrain independently of character movement. It accepts no client-reported carrier or displacement. It retains at most 0.5 seconds of exact shuttle surface poses so delayed character updates can still be matched to the terrain they stood on. The fallback uses the same footprint and feet-height tests against a real historical surface. Jumping, rising velocity, pending Updraft, expired history and unrelated parts reject it. A stationary unsupported pose stops matching when that finite history expires.

The history was extended from 0.2 seconds after a replay of the captured shuttle corner showed that 0.4 seconds of combined terrain/character delay could lose contact for more than a second. This change preserves ground/skill contact under delayed replication; it does not alter physical platform size or introduce a flying exemption. Native Studio rider tests remain necessary to assess actual network behaviour.

## Movement and falls

Updraft is the only active skill. The server approves an absolute target velocity; the owning client applies the corresponding impulse once. A spent airborne charge rearms after0.12seconds of stable grounded contact independently of its3.25second cooldown; activation still requires that cooldown to have elapsed. After arming, a later jump can activate when the timer expires. Restarting does not shorten its cooldown.

Grounding uses server raycasts against collidable active-map parts and correct R6/R15 root-to-feet dimensions. The centre probe falls back to eight probes inside a maximum 0.8-stud radius, because a humanoid can stand on a platform edge while its root centre is outside that edge. Ground support must face upward, lie within 0.55 studs of actual foot height, and have observed vertical speed below 12 studs/second. Wall proximity, surfaces above the feet and distant floors cannot grant grounding.

Automatic speed/flight correction has been removed at the user's request. The server no longer teleports players based on estimated speed, airborne duration, ascent allowance or missed landing evidence. It also no longer withholds stage/finish credit while such estimates settle. This avoids normal jumps and delayed shuttle rides being classified as invalid movement. It means this version does not prevent arbitrary client-owned speed, flight or teleport exploits; the remaining checks should not be described as complete movement anti-cheat.

Server control remains in place for Updraft cooldown/recharge, action eligibility/rate limits, course bounds, hazard contact, authored grounded stage progress, exact grounded finish contact and duplicate reward prevention. Non-finite (NaN/infinite) position or velocity still invokes recovery to the last verified static landing, or the start when no valid anchor remains. This safety path preserves the attempt's earned progress and running clock and does not increment the normal reset counter. Manual restart and character respawn clear old recovery anchors. The client clears pending skill impulses and platform carrying on recovery.

Hazards use a forgiving lower-body contact volume. Swept contact is used only between nearby samples (at most 3 horizontal and 2 vertical studs); larger replicated jumps require overlap at the current position. This prevents a straight chord between packets from inventing contact underneath an actual jump arc. Visible hazard overlap still resets the attempt.

The complete contact check runs every Racing Heartbeat. Client state broadcasts remain throttled to four per second. Falling onto a lower platform continues the same attempt: current altitude decreases while peak altitude and previously cleared milestones remain recorded. Bottom void, actual hazard contact, leaving course bounds, manual restart or death starts a fresh attempt. The race clock continues and stage claims stay consumed.

## Movement diagnostics

`Feedback('Reset', message, {reason, reasonCode, count})` accompanies normal course/manual resets. `DasherLastResetReason` exposes the most recent code on the player. Current codes are `CourseBounds`, `HazardContact` and `ManualRestart`. Character respawn also emits the existing `Reset` feedback without an extra table, so consumers must allow missing details.

`Feedback('MovementCorrected', message, {reasonCode, count})` is retained only for invalid numeric physics, with reason code `NonFinitePosition` (covering both position and velocity). `DasherLastMovementReason` and `DasherMovementCorrections` expose this safety recovery on the player. `SustainedSpeed` and `SustainedFlight` are no longer emitted.

## Remaining protocol

Actions: Ready, Updraft, Restart, Accelerate, Vote, Spectate, Buy, Equip, ClaimDaily, ClaimWeekly. Server actions remain type-checked and rate-limited. Exact boolean `Spectate(false)` retains the immediate, idempotent exit path; stopping the camera never restores a forfeited run.

The client sends `Restart` after its hold-to-reset interaction completes. Holding is a local input safeguard against accidental resets; server reset eligibility and rate limits still apply independently.

`Feedback('Updraft', '', {at, velocity})` is the sole ability impulse approval. `SkillFX('Updraft', {userId, position, at})` is the sole ability effect. `abilities` includes `updraftAt`, `updraftReady`, `updraftAirUsed`, `updraftArmed` and the absolute server timestamp `updraftReadyAt`. The client derives the timer locally but the server validates every activation. Round state adds `finalSprint`, `roundEndReason` and `raceCapacity`. Altitude, spectators, votes, cosmetics, daily/weekly progression and weekly leaderboard contracts otherwise remain compatible.

## Persistence and migration

`CourseVersion=6` gives the redesigned towers their own best times while preserving coins, XP, cosmetic ownership/equipment and archived earlier records. Existing profile session locks, unknown-schema protection, failed-read safeguards and Studio memory isolation are retained. Weekly ordered scores still publish only exact successfully saved finish-score snapshots, with batched writes and throttled reads. Real-money products are not enabled.

## Validation

Current source-bound server suites live under `work/ascent07-qa`:

- `movement-regressions.py`: 41 checks of actual contact, finite-physics recovery, teleport, terrain movement and respawn/restart functions. Cases include repeated buffered jumps with 0.05–0.35-second pose updates, edge standing, backward movement, long falls, R6/tall R15 avatars, transient packets, removal of speed/flight teleporting and progress suppression, rejection of airborne rewards, precise finish contact and jump-chord hazards.
- `finish-regressions.py`: 91 finish/reward/entrant/round-loop checks, including duplicate/rejoin protection, ten simulated racers, first-finish sprint, departure, forfeit, timeout and Results-to-next-round cycling.
- `moving-support-tests.py`: 30 checks of exact bounded shuttle-history contact, invalid contact rejection and history pruning.

These tests execute current source under controlled service/physics mocks and record source hashes. They do not establish live ten-client performance, every avatar's physical traversal, arbitrary network conditions or live persistence. Native Studio evidence and any remaining limits belong in TESTING.md.

Roblox's [network ownership and movement validation guidance](https://create.roblox.com/docs/scripting/security/network-ownership) explains why client-owned physics requires latency-aware server checks. Its [client-server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary) covers validation of remote inputs and game context. Remote and reward checks follow these principles. Automated movement policing is deliberately absent in this build. Additional engine references: [moving objects](https://create.roblox.com/docs/tutorials/use-case-tutorials/physics/create-moving-objects) and [Model/PivotTo](https://create.roblox.com/docs/reference/engine/classes/PVInstance).
