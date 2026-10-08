# Dasher — a tower climb shaped by iteration

**Kuzey (Lloydhf): concept, game design and creative direction.** OpenAI Codex assisted with implementation, debugging, tests, build tooling and documentation. Promotional artwork was generated with ImageGen and is labelled separately from gameplay evidence.

## Design question

How can a competitive tower climb make route execution matter while giving a player a chance to recover from a mistake? Dasher uses a limited Updraft, branching routes and physical lower ledges. A player who catches a ledge can continue; a fall into the void starts the attempt again while the race clock continues.

The project evolved from a horizontal dash racer into three vertical towers. Kuzey directed the move toward a playable Roblox game, the single-ability focus, the open-air presentation and the removal of movement correction that interrupted legitimate play.

## Decisions visible in Ascent 0.7

| Decision | Purpose | Tradeoff to observe |
| --- | --- | --- |
| One Updraft, with cooldown and landing recharge | Give route timing a clear shared constraint | Whether players understand when a landing rearms the ability |
| Alternate routes and physical fall catches | Reward route reading and allow partial recovery | Whether beginners can identify the next safe landing |
| Remove automatic speed/flight correction | Stop false positives from pulling ordinary jumps and shuttle riders backward | Less movement-exploit policing; public-server abuse still needs evaluation |
| Require grounded summit-pad contact | Make the end of a run match the visible finish | Whether the finish marker is immediately readable |
| Hold reset for 1.1 seconds with cancellation and progress | Reduce accidental restarts | Whether the delay feels responsive on different input devices |
| Open-air maps and a route-facing intro | Show the climb without enclosing walls or obstructed camera views | Orientation and depth perception for a first-time player |
| Cosmetic rewards and independent avatars | Keep competitive movement independent of purchases and body blocking | Whether cosmetic progression and indirect competition sustain interest |

These are design intentions, not measured retention or enjoyment results.

## A concrete before-and-after

In Ascent 0.5, the broad Canopy summit sensor accepted contact on the final approach before a P064 landing. Ascent 0.7 waits for standing contact with the marked finish pad. Its native check visited every P001–P064 platform, waited on CrownDeck without finishing, then entered FinishPad. That makes the finish rule easier to explain and gives the test a stricter visible target.

Another iteration addressed false movement corrections: native shuttle and jump checks exposed situations where the server pulled a legitimate player backward. Following Kuzey's decision, version 0.7 removed automatic speed/flight policing while retaining hazards, fall handling, once-per-round rewards and explicit restarts.

## Evidence

The original October gameplay task completed all three towers, all 192 main-platform landings and exact finish-pad contacts using normal Humanoid movement and approved Updraft. It recorded no unexpected resets or detected game-script runtime errors. A separate native session checked rendered hold progress, early cancellation and one reset per hold.

The GitHub refresh revalidated those archived artifacts and reran 560 deterministic checks/replays, six geometry groups and the camera geometry audit. It did not start another native gameplay session. [Testing detail](TESTING.md) separates source checks, archived Studio evidence and remaining gaps.

## Next evidence to collect

A short gameplay recording and sessions with new players would make the design work easier to assess. Useful observations are first-sector success, failures by obstacle, reset attempts, time to the first cosmetic and voluntary replays. Ten-player server behavior, physical mobile/controller input and live persistence also need verification.

For the current build, use the [play guide](../BASLA.md), [design notes](DESIGN.md) and [map specification](MAP-DESIGN.md). The separate [onboarding research proposal](https://github.com/Lloydhf/game-design-research) supplies a possible future study; no participant outcomes are claimed here.
