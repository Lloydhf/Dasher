# Dasher — designing a competitive tower climb

**Concept, game design and creative direction: Kuzey (Lloydhf).** Implementation, build tooling and documentation include OpenAI Codex assistance.

Dasher began as a horizontal dash racer and now focuses on a vertical Roblox tower obby. The current **Ascent 0.5** build has three authored towers, a single Updraft ability and a social garden atrium. The shift follows Kuzey's design direction toward a playable, evolving Roblox game with readable challenge and cosmetic progression.

## Current design problem

How can a tower climb reward execution and route choice while allowing players to recover from some mistakes? In Ascent, a falling player can land on physical lower ledges and continue climbing. There are no saved checkpoints. Hazards or a fall into the void return the player to the base while the shared race clock continues.

| Decision visible in the build | Intended effect | Tradeoff to test with players |
| --- | --- | --- |
| One Updraft with a 3.25-second cooldown and a required landing before reuse | Make timing and route planning matter | Whether the cooldown and landing states are easy to distinguish |
| Alternate routes and physical catch ledges | Offer route choices and opportunities to recover | Whether new players can read the next jump and recovery route |
| No combat or avatar body blocking | Keep competition about traversal | Whether indirect competition provides enough excitement |
| A ten-racer roster, tower votes and spectating | Support a shared race loop | Real server performance and the experience of waiting players |
| Once-per-round sector rewards and purely cosmetic purchases | Acknowledge progress without selling movement power | Time to first cosmetic and whether players want another round |
| Garden atrium NPCs and a compact race HUD | Put services in the world while keeping the course visible | Discoverability, camera comfort and mobile readability |

These are design intentions. No retention, enjoyment or commercial outcome has been measured.

## Inspect the iteration

Download and extract [Dasher-Studio.zip](../Dasher-Studio.zip), then open its **Dasher.rbxlx** in Roblox Studio using the included [Turkish quick-start guide](../BASLA.md). Try a main route, one alternate branch and a recovery onto a lower ledge. Compare the reward and movement values in `src/shared/Config.luau` with the intended experience.

The [current design notes](DESIGN.md), [route specification](MAP-DESIGN.md), [client notes](CLIENT.md) and [server notes](SERVER.md) explain the implementation. [Next 0.2's earlier case study](history-v0.2/PORTFOLIO.md) remains available as history; its dash mechanics no longer describe the current game.

## Evidence and next questions

The preserved native Studio run from **24 September 2026** finished Helix, Canopy and Reactor with 24 approved Updrafts and no resets or game-script runtime errors. Canopy finished through summit-sensor contact during the P063-to-P064 approach; a P064 landing was not observed there. The GitHub refresh revalidated that archived artifact against the current gameplay sources and geometry, rebuilt the production file exactly, and reran the portable logic and geometry checks. It did not conduct a new native gameplay session.

Read [TESTING.md](TESTING.md) for the coverage and limits. Automated traversal establishes a feasible route under the tested conditions; it cannot establish that the difficulty is enjoyable. Native ten-client load, real mobile devices, live persistence and human playtests remain outstanding.

The separate [game-design research project](https://github.com/Lloydhf/game-design-research) proposes comparing movement-instruction timing. Its experiment has not been run in this release. The most useful next portfolio evidence is a short gameplay recording, observations from new players and Kuzey's explanation of one decision revised after those observations.
