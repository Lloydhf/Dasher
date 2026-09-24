# Ascent client v0.5

One active skill: **Updraft**. The rounded **Nunito / Fredoka One** pairing from the original Tower release is restored. The permanent interface contains a compact clock, level/XP balance, height rail and one ability button. A small race-position button on wide screens opens the live ten-runner board; smaller screens reach the same board through Menu → Live Race. The height rail is hidden on short landscape screens, with height percentage shown alongside run time instead.

## Controls

| Action | Keyboard | Controller | Touch |
| --- | --- | --- | --- |
| Move / jump | WASD / Space | Stick / A | Roblox controls |
| Updraft | Q | X | Updraft button |
| Reset attempt | R | Y | Reset |
| Drawer | Tab / H | View | Menu |
| Spectator previous / next | On-screen arrows | LB / RB | Arrows |
| Exit spectate / close drawer | On-screen X | B | X |

Inactive ability input passes through so merchant NPC prompts remain available. Shift retains Roblox's normal camera behavior. Players cannot push, damage, or interfere with each other through a client ability.

## Authoritative movement and rewards

`Action("Updraft")` requests a lift. There is no predicted lift. Only `Feedback("Updraft", "", {at, velocity})` applies the exact approved velocity once through a mass-scaled `ApplyImpulse`. Duplicate approvals and approvals older than a respawn/reset boundary are discarded. Cooldown, grounded rearm, run eligibility and movement validation belong to the server. The client uses `abilities.updraftArmed`, `updraftReadyAt`, the last approved impulse timestamp and `workspace:GetServerTimeNow()` for both button state and input. A stale periodic `updraftReady=false` cannot add extra delay after the configured **3.25-second** cooldown. A local approval prevents a stale ready snapshot from falsely showing another available lift. Same-round restarts preserve that timestamp; new rounds clear it. The display distinguishes a remaining countdown from a fully charged skill that still needs a landing.

`SkillFX("Updraft", {userId, position, at})` presents the short wind ring, vertical streaks and procedural R6/R15 lift pose. These local effects do not collide, move platforms or carry avatars.

Moving shuttles are positioned by the server. The character's network-owning client applies the observed platform CFrame delta in `PreSimulation`, with no predicted terrain motion and no client-reported allowance. Transport requires contact with the same anchored Shuttle part before movement and a downward ray confirming the proposed contact after movement. The foot distance follows R6/R15 dimensions. Walking off, jumping, an Updraft request/approval, a reset, a round change or airborne vertical speed releases contact immediately. Deltas larger than 8 studs are rejected. The server separately verifies rider contact and accounts for bounded platform displacement; it must not also pivot the character.

An unanswered Updraft request temporarily suspends transport; approval or denial immediately clears that request timer. Approval adds a separate 0.2-second guard for the impulse's first physics evaluation. This is shorter than the lift's flight time, so a later verified landing can acquire its moving platform without waiting for a fixed flight timeout.

`Feedback("StageCompleted", message, {stage, coins, xp})` displays the server's stage reward. The client never creates a coin or XP award. Profile snapshots drive the coin balance, level and XP bar; level increases receive a short notification. Repeating a stage after a fall does not award it again in the same round.

Stage markers use `altitude.totalStages`, so the UI follows the current course. Current height falls when the avatar falls; it is separate from already-cleared stages and already-paid rewards.

## Movement particle cosmetics

The existing cosmetic IDs and `EquippedTrail` attribute are retained for saved ownership compatibility. Their presentation is now genuine `ParticleEmitter` effects behind moving avatars. Each client renders the selected effect on every nearby avatar from the replicated equipped ID.

| Saved ID | Optional `particleStyle` | Visual character |
| --- | --- | --- |
| ice | crystal | Small square crystals |
| solar | glow | Soft golden light points |
| orchid | petal | Spinning, slowly falling petals |
| mint | leaf | Narrow tumbling leaves |
| ember | ember | Rising warm sparks |
| cobalt | comet | Slim streaks aligned with motion |
| pearl | snow | Drifting, falling star flakes |
| prism | prism | Rotating squares with a changing color sequence |
| crimson | sparks | Short, falling fast sparks |
| aurora | mist | Sparse, soft colored mist |

`Config.Cosmetics[].particleStyle` is optional; the ID mapping above is the fallback. `color` and `price` keep their existing meaning. These are distinct texture, size, rotation, acceleration and lifetime treatments rather than color-only variants.

Only textures bundled in Roblox are used: `SquareParticle.png`, `sparkles_main.dds`, `fire_sparks_main.dds`, `smoke_main.dds`, and `forcefield_glow_main.dds`. Rates stay between 5 and 12 particles per second, scale down at lower movement speed, stop when idle, and disable beyond 130 studs from the camera. Lifetimes are at most 1.3 seconds. Reduced Motion disables and clears trailing particles. Equip changes, respawns, player removal and script cleanup destroy previous attachments and disconnect listeners.

Shop and Inventory use two-column tiles with a stylized runner silhouette and animated trail samples. Samples use the corresponding bundled texture, color, size and rotation treatment; they are 2D illustrations, not a rendered avatar or a promise of exact in-world appearance. Only visible tiles animate while the menu is open; Reduced Motion makes samples static. Scrolling, price, owned and equipped states are retained on small screens.

Purchases use the existing server `Buy` / `Equip` actions. Stage coins can buy effects through Shop; owned effects appear in Inventory. No client purchase or ownership mutation exists. The drawer balance updates on profile snapshots.

## Camera and drawer

- Lobby reveal lasts about 6 seconds; map reveal lasts about 4 seconds within the longer countdown.
- The final portion blends into an ordinary third-person angle so gameplay starts facing the landings instead of the underside of the tower.
- Reveals can be skipped and are bypassed by Reduced Motion. Phase changes and respawns restore camera ownership; a race never waits for a cinematic.
- Ordinary menu/spectator exits preserve the player's camera orbit. Pending spectator exits recover through server acknowledgement, including rapid toggles.
- The six primary drawer pages are Home, Shop, Inventory, Quests, Leaderboard and Settings. Help, live Race and Watch remain available from Home; Results is contextual.
- Live Race shows all ten participants, actual current height and cleared stage. Finishers are ordered by the server's recorded finish order, ahead of runners still climbing. Equal heights use a stable user-ID tie break; the live height position is not a permanent finishing rank.
- Personal finish feedback immediately opens a summit card with rank, real time and earned coins. A snapshot containing a newly finished player also opens it, so the presentation does not depend on a single transient notification. Results / Watch remain directly available.
- The first finish announces Final Sprint to remaining runners. Server phase changes remain authoritative; the client never extends a race or delays its end.
- Portrait touch layout places the Updraft control above Roblox's native movement controls.
- Short landscape canvases below 390 pixels high and 800 pixels wide use a smaller clock, profile pill and single ability dock. At 568×320, persistent HUD rectangles total 26,144 square pixels (14.4%, including the transparent run-time label; the height rail is hidden). This is a source-layout calculation, not a native screenshot measurement. "How to play" is available from Home.

## Lobby NPC and theme contract

The client accepts `Workspace.Lobby` (or `DasherLobby`) containing merchant NPC models. A station's anchored root part has a `StringValue` named `MenuPage` set to `Shop`, `Inventory`, `Quests` or `Leaderboard`, with optional `NPCName`. An authored `ProximityPrompt` such as `StationPrompt` is reused rather than duplicated. Only stations without an existing prompt receive a fallback prompt. The prompt's server-authored caption, distance and controls are preserved. Added stations are bound dynamically; legacy parts named after the page are also supported.

Lobby parts with a child `StringValue` named `LobbyTint` adopt `Config.Maps[mapId].accent`: `accent` uses that color; `soft` blends toward a pale stone tone. Changes ease over 0.8 seconds (instant with Reduced Motion), and tagged parts' lights/emitters receive the same color. Unmarked stone, water and foliage stay in their authored materials and colors.

## Validation boundary

The client compiles with `luau-compile --null`. An extracted-source Luau harness checks cooldown boundaries, stale ready flags, approved-impulse deadlines, grounded rearm, finish order, equal-height ties and ten-runner retention (**18 checks**). It does not simulate Roblox GUI rendering. Actual NPC interaction, moving-platform behavior, particle appearance, small-screen layout and multiplayer results must be recorded by the main Studio QA run. Disposable QA scripts must never be appended to a release file.

API references checked: [Font enums](https://create.roblox.com/docs/reference/engine/enums/Font), [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter), [ApplyImpulse](https://create.roblox.com/docs/reference/engine/classes/BasePart#ApplyImpulse), and [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera).
