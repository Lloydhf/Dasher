# Dasher Ascent 0.5 verification

This document concerns CourseVersion 5 only. Prior 0.4 native playthrough and multiplayer results do not establish this version's playability.

## Server and client checks

- **95 finish/lifecycle regressions:** extracted actual server functions, actual profile and rule modules, with deterministic service mocks. Covers skipped stage rests, once-only stage/finish rewards, reconnect claims, ten entrants and distinct slots, ten finishers, departures/forfeits, race expiry and subsequent rounds. This is not a native ten-client load test.
- **23 movement integration cases:** actual teleport initialization and movement validation/ground-support functions under controlled vector, raycast and clock inputs. Covers narrow valid landings, expired hovering rejection, teleport grace, ascent/distance budgets, and the 0.12-second grounded recharge without bypassing the 3.25-second cooldown.
- **18 client readiness/ranking checks:** actual client helper functions. Checks cooldown display/readiness boundaries and finish ordering. Does not substitute for rendered UI checks.
- **30 moving-support checks:** actual server-authored shuttle history and ground-support functions, including the captured native failure pose. Recent support expires after 0.2 seconds and cannot excuse airborne ascent, stale geometry or a missing platform.
- **35 client carry checks:** actual carrier code with deterministic transforms and raycasts. Includes valid edge/corner contact, the full 18-stud shuttle trip, player movement, jump/Updraft detachment, old-character cleanup and rejection of unrelated surfaces. These mocks do not simulate Roblox replication.

Reports in the original QA work directory bind their tested source and harness hashes. The portable harnesses are now included under [tests/](../tests/README.md); their 201 checks were rerun during the 24 September GitHub refresh against the unchanged production sources. The three geometry regression tests also passed. [PUBLICATION-VERIFICATION.json](PUBLICATION-VERIFICATION.json) records this refresh separately from the native evidence. Refresh any affected report after source changes.

## Native physics protocol

The local-only QA place embeds the unmodified production client/server and a separate input-driving harness. The harness drives normal Humanoid walking/jumping and requests the public Updraft action. It does not teleport the character, change physics, disable hazards or grant movement exemptions.

The archived 24 September 2026 native run finished all three towers on its first attempt, with **zero resets, 24 approved Updrafts and zero game-script runtime errors** in the artifact-scoped Studio log. It traversed a representative first-sector alternate branch out-and-back, observed Results after a finish and entered the next race automatically.

| Tower | Native completion time | Observed route coverage |
| --- | ---: | --- |
| Helix | 109.88 seconds | P001–P064 landings, followed by crown sensor contact |
| Canopy | 107.85 seconds | P001–P063 landings; summit sensor contact during the final approach toward P064 |
| Reactor | 109.88 seconds | P001–P064 landings, followed by crown sensor contact |

Canopy's broad finish sensor, including the existing 2.2-stud body-contact padding, intersects the final P063 approach toward P064. The server therefore completed the run before P064 landing. This is accepted summit-sensor contact under the existing finish contract; **a P064 landing was not observed on Canopy**. The verifier allows only this final-pad exception, checks the exact artifact geometry and final event sequence, and still requires every earlier landing and all eight Updrafts. No intermediate missing platform is excused.

Only countdown is shortened to 5 seconds for QA. Intermission 18 seconds, results 10 seconds and the 420-second race limit match production. An optional walk to the shop NPC after completion is recorded separately from route verification.

**Status: native verification passed.** Artifact `native05-1790245491`, SHA256 `d6092000df259c9b299db6fb8b55f25b958e75c4beac61eaed47f2837902fe94`. Production place SHA256 `b643dd193ee79a5a63986d73621df74943d1ec15141999c009db143c963c0a2f`. `verify_native.py` checks source hashes, exact non-script geometry equivalence, the route coverage above, current-artifact runtime errors and lifecycle evidence. Prior-version and incomplete runs are rejected.

Earlier attempts found an edge-rider replication issue on the smaller shuttle and an overhead collision at a narrow takeoff. The carrier and server support now share footprint-aware checks, with a strict 0.2-second history of actual server-authored shuttle poses. A clear jump lane and one Helix section rotation remove the overhead conflicts. The final run above uses those changes; earlier failed attempts are retained and are not counted as passes.

The optional post-completion smoke setup walked normally around the fountain to the shop NPC and logged `lobby_shop_ready` at a distance of 8.13 studs. This proves arrival within the prompt's 10-stud range; it does not by itself prove that the shop opened or a purchase succeeded.

During the original gameplay task, Codex then visually tested the real shop and inventory in the same native Studio session: buying SOLAR for 120 coins reduced the earned balance from 132 to 12, automatically equipped SOLAR, and added it alongside ION in Inventory. Equipping ION and then SOLAR both updated successfully. This was an isolated Studio profile, not a live persistent purchase or Robux transaction.

The separate UI smoke artifact `npc-ui-1790246402` used a 180-second intermission to leave time for the physical prompt test. It retained the production geometry and gameplay source, adding only the Studio test configuration and an ordinary Humanoid walking driver. The driver walked around the fountain to MILO, logged `npc_ready` at 7.59 studs and released controls. During that original task, Codex observed MILO's **E Browse** prompt, pressed E and visually confirmed that the **TRAIL STUDIO** shop drawer opened with the expected items and prices. This UI-only test did not replace the route artifact or change the production place.

## Boundaries

- No live publication, real Robux transaction or purchase receipt fulfillment was tested.
- Studio uses isolated session profiles; live persistence must be checked separately after deployment.
- Ten-player logic checks do not measure a real ten-client server's performance or network behavior.
- Real mobile devices, controller hardware, unusual avatar bundles, high latency and player retention still need playtesting.
- Automated traversal proves a possible route under the tested conditions. It cannot establish that every player will find the difficulty enjoyable or that every optional hazard phase was explored.
