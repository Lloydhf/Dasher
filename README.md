# DASHER

**One dash. Three worlds. Back to the start.**

A round-based Roblox parkour racer by Kuzey. Players keep their own avatars and race through three handcrafted courses. Every fall returns to the start: timing and clean landings matter.

## Open the game

1. Download and extract **Dasher-Studio.zip** from this repository, then open **Dasher.rbxlx** in Roblox Studio (`File > Open from File`). If you already have the local project folder, open its **Dasher.rbxlx** directly.
2. Press **Play / F5**. A short intermission leads into the first race.
3. The three courses rotate automatically: **Cloudline → Afterhours → The Grid**.

The place embeds all scripts and map geometry. **No plugins, HTTP requests, paid assets or API keys are needed to play locally.** The `.rbxlx` extension is Roblox's editable XML place format; Studio can save it as `.rbxl` if preferred.

## The courses

| Course | Setting | Focus |
| --- | --- | --- |
| Cloudline | Sunlit suspended architecture, cloud forms and side walls | Clear landings, lateral routes, dash distance |
| Afterhours | A neon city alley above a dangerous street | Precise ledges and rhythm |
| The Grid | A four-wall geometric obstacle chamber | Exposed timing and clean execution |

Rounds last four minutes. The first finisher can accelerate the shared countdown once. Personal run times always use real elapsed time. Finishing earns coins once per round, with a small podium bonus. Coins unlock visual trails only; no trail changes speed, cooldown or jumping.

## Local progress versus published progress

Studio sessions use **temporary coins and records** deliberately. Closing Play resets them. This protects real player data during development. Published servers use `DataStoreService` with session ownership, serialized updates and autosaves. If a profile cannot be loaded, that session cannot overwrite the saved profile. See `docs/TESTING.md` for release checks and limitations.

## Source layout

```
src/shared/Config.luau                 movement and presentation tuning
src/server/DasherServer.server.luau    rounds, validation, rewards
src/server/ProfileStore.luau          persistence and cosmetic transactions
src/client/DasherClient.client.luau    responsive UI, input, movement feedback
tools/world.py                        deterministic editable map geometry
tools/build.py                        standalone place builder (Python stdlib)
tools/StudioQA.server.luau             isolated Studio test harness
docs/                                design decisions and verification notes
```

Rebuild after source changes with `python tools/build.py`. Build an isolated accelerated test place with `python tools/build.py --qa --output Dasher-QA.rbxlx`. The test harness is **not included** in the normal release place.

## Authorship and portfolio

Concept, direction and final playtesting: **Kuzey**. Implementation assistance: **OpenAI Codex**. Keep before/after recordings and player observations in the design journal. Only claim work and tests actually performed. This game is a portfolio project; it does not replace any university's individual admission assignment.

All geometry and UI are constructed for this project. No third-party map packs or executable Toolbox models are included. Built-in Roblox resources remain subject to Roblox's terms. No open-source license has been granted for this repository yet.
