# DASHER · NEXT 0.2

**Find your line. Save your dash. Finish together.**

A competitive Roblox parkour racer directed by Kuzey, with implementation assistance from OpenAI Codex. Five long courses, a new social atrium, map voting, spectator cameras and cosmetic progression. Falls return to the start; there are no checkpoints.

## Play

Download and extract **[Dasher-Studio.zip](Dasher-Studio.zip)**. Open the included **Dasher.rbxlx** in Roblox Studio with **File → Open from File**, then press **F5 / Play**. Alternatively, rebuild the place from this repository with `python tools/build.py`. The map is selected after a 20-second voting intermission. A round lasts up to six minutes. The first finisher may accelerate the shared countdown; individual times stay in real seconds.

The editable place includes all source and geometry. No plugins, API keys, HTTP access or paid assets are required. Dasher-Studio.zip contains this release place and the Turkish quick-start guide. Test places are deliberately outside the release folder.

## This iteration

- Charcoal atrium with cyan accents, seating, four interactive kiosks and a short camera introduction.
- Small gameplay HUD, one menu launcher, animated panels and spectator controls.
- **Cloudline, Afterhours, The Grid, Foundry and Zenith**: 74 main-route platforms and optional dash forks per course; 24 ordered validation gates.
- One dash recharges in **3.8 seconds**. Ordinary jumps complete the main route; forks reward dash timing.
- Finish reward **14 coins**, plus podium bonuses **6 / 3 / 1**. Ten purely visual trail styles, including the starter trail.
- Three-choice voting. Finishers can watch racers; voluntarily spectating an unfinished run forfeits that round.
- XP and levels, a claimable **25-coin daily reward**, and a weekly **10 finishes → 80 coins** objective. No missed-day penalty.
- Weekly ranking based on race results, stored separately for each UTC week.

## Deliberately deferred

Team races, additional movement skills, a season pass, stage skips and Robux sales are not active. Monetization configuration is disabled with zero product IDs. The shop accepts earned coins only. Next priorities depend on first-course completion, repeat attempts, camera comfort, mobile performance and map preference.

Before adding developer products, implement and test server-side receipts, duplicate-receipt protection and durable grants. A purchase prompt alone is not fulfilment. Keep competitive movement independent of purchases.

## Saved progress

Studio uses temporary data even when API access is enabled. Published servers use the existing DasherProfiles_v1 store with schema migration, session locks and serialized updates. Existing coins and owned trails remain. Old short-course times are archived separately because routes are no longer comparable. Failed reads cannot replace saved progress with defaults.

The weekly leaderboard uses memory in Studio and an ordered data store in published servers. Live cross-server persistence needs a controlled published test. See [verification notes](docs/TESTING.md).

## Source and iteration

src/shared/Config.luau controls balance. src/server owns rounds, voting, progression and ranking. src/client owns input, UI and cameras. tools/world.py generates editable parts; python tools/build.py embeds them in the place. No unreviewed Toolbox scripts are included.

See [design and research](docs/NEXT-DESIGN.md), [map specification](docs/MAP-DESIGN.md), and [testing](docs/TESTING.md). Rebuild after source changes. Never upload files named QA or LOCAL_TEST_ONLY.

For a portfolio introduction, read the [case study](docs/PORTFOLIO.md). A separate [onboarding research proposal](https://github.com/Lloydhf/game-design-research) asks when to present movement instructions; its A/B variants and participant study have not yet been implemented.

Publication verification on 20 September 2026 rebuilt the place, checked all six embedded source files and 6,122 unique instance references, and excluded the StudioQA script from the normal place. Earlier Studio results remain dated in the verification notes; Studio gameplay was not rerun during publication.

Geometry and UI were constructed for this project. Roblox built-in resources remain subject to Roblox terms. This repository does not currently grant an open-source license.
