# Dasher — Ascent 0.5

**Concept, game design and creative direction: Kuzey (Lloydhf).** Implementation, build tooling and documentation include OpenAI Codex assistance. [Read the design case study](docs/PORTFOLIO.md).

A competitive Roblox tower obby for up to **10 racers**. Choose your route through three towers: Helix, Canopy and Reactor. Updraft is the only active ability; avatars cannot push or attack each other.

Download and extract **[Dasher-Studio.zip](Dasher-Studio.zip)**, then open **Dasher.rbxlx** in Roblox Studio and press **F5**. The source and editable place are also included in this repository. If Windows does not open the file directly, open Studio first and use **Ctrl + O** to select it. See **BASLA.md** for the Turkish play guide.

## This version

- Wider jumps, narrow beams, moving shuttles, disappearing steps and alternate routes that rejoin the climb.
- Required Updraft climbs, with physical lower ledges that can catch a fall. These are not teleport checkpoints.
- A broad, visible summit platform. Reaching the finish does not require touching one prescribed sequence of stage pads.
- A garden atrium with a tiered fountain, hanging greenery and four NPC services: Shop, Inventory, Quests and Leaderboard.
- Restored Nunito / Fredoka One typography, animated cosmetic shop tiles, live race standings and immediate personal finish results.

## Race loop

Vote for a tower during the 18-second intermission, then prepare during the 8-second countdown. A race lasts up to **7 minutes**. The first finisher starts a final sprint with at most **90 seconds** remaining. The round also ends when no unfinished active racers remain. A 10-second results phase leads to the next vote.

**Q** activates Updraft. Its cooldown is **3.25 seconds**, and another lift requires a brief landing. The ability meter distinguishes a cooldown from a charged ability that still needs a landing. Falling onto a lower platform keeps the run going; **R** restarts from the base without resetting the round clock.

The race roster allows ten entrants. Configure the published experience's server size to **10** as well. Local Studio sessions do not automatically provide ten players; use Studio's multiplayer test controls or invite real players after publishing.

## Progression

There are eight sectors per tower. Validated course landings advance progress across alternate routes. Each newly credited sector earns **3 coins and 25 XP**, once per round. Finishing reconciles any outstanding sector rewards and adds **14 coins**, with **6 / 3 / 1** bonus coins for the first three finishers, plus finish XP. Falling or restarting cannot repeat a paid sector reward.

Coins buy ten cosmetic movement-particle effects; they do not change abilities, speed or jump height. Approach a lobby NPC and press **E**, or use Menu to open the same pages. Shop offers animated samples and real owned/equipped states.

Previous balances, cosmetic ownership and XP are preserved. **Course version 5** archives old course records because the routes changed. Studio uses temporary session data. To retain an existing published game's player data, update that same experience rather than creating a different one.

## Source and release

- `src/client`: HUD, camera, input, Updraft feedback and cosmetics.
- `src/server`: rounds, validation, rewards, terrain motion, profiles and rankings.
- `src/shared/Config.luau`: timings, currency, cosmetics and maps.
- `tools/world.py`: tower geometry and route metadata.
- `tools/lobby05.py`: garden atrium and NPCs.
- `tools/build.py`: Python build; run `python tools/build.py`.

No external Studio plugin is required. Robux purchases are disabled in this version. Live publishing is a separate step; saving this local file does not update the published game. Use **Dasher.rbxlx**, not a file from `work/ascent05-qa`, when publishing.

See `docs/REFERENCES.md` for research and `docs/MAP-DESIGN.md` for route details. Verification must refer to this exact version: earlier v0.4 native passes are not v0.5 passes. Consult the final `docs/TESTING.md` for recorded coverage and outstanding playtests; a geometry or source check alone does not establish native playability.

## Verification and portfolio context

Updated on **24 September 2026** from the hash-verified Ascent 0.5 package. The production place rebuilds byte-for-byte; all eight embedded gameplay scripts match their source. The refresh reran **201 deterministic logic checks** and **3 geometry regression tests** covering 339 route transitions. [Run the checks](tests/README.md).

The earlier native Studio evidence from the same date was revalidated against the current source and geometry; Studio gameplay was not rerun during this GitHub refresh. [Verification details](docs/PUBLICATION-VERIFICATION.json) separate these checks from archived gameplay evidence. This repository update does not publish a Roblox experience.

The [onboarding research proposal](https://github.com/Lloydhf/game-design-research) is a separate work in progress; its A/B experiment has not been run here. Historical Next 0.2 documentation is preserved under [docs/history-v0.2](docs/history-v0.2/INDEX.md).

Geometry and UI were constructed for this project. Roblox built-in resources remain subject to Roblox terms. This repository does not currently grant an open-source license.
