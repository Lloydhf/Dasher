# Dasher Ascent — v0.7 tower routes

The three towers now have an open-air silhouette, matte platform faces and slim colour accents attached directly to each platform. At the user's request, the opaque enclosing walls, high circular rims and vertical cage ribs were removed. Orphan floating planters, leaves, vines, status lights, pool/ring and detached wall panels were also removed. Platform routes, physical recovery ledges, Updraft climbs and the finish pad are unchanged by these visual revisions. No third-party models or game assets were imported. The lobby and its NPCs are retained from 0.6.

## Layout and difficulty

Each tower has eight 26-stud sectors, 64 numbered primary platforms, 34 alternate platforms, a launch deck, a crown and eight physical recovery ledges. The crown surface is Y232, 210 studs above the launch. There are fourteen explicit branch choices per tower. Lower platforms and catch ledges physically support falls; progress metadata does not teleport players.

| Course | Normal edge gaps | Course parts | Visual character |
| --- | --- | --- | --- |
| Helix | 4.295–8.2 studs | 554 | Matte ice/lavender faces, dark navy undersides and attached cool-blue edge strips |
| Canopy | 4.243–8.6 studs | 554 | Matte jade/sand faces, deep green undersides and attached sage edge strips |
| Reactor | 4.5–8.6 studs | 554 | Matte steel/cyan faces, graphite undersides and attached teal edge strips |

Distances use the true edges of oriented support faces. Typical primary islands are 4.8–5.6 studs wide. Lift launch pads are 9.2×9.2 and receivers remain a forgiving 10×10. Precision running jumps are separated from rest decks of 14×14. New optional 7.8×2.8 angled beams replace ten branch islands in Helix/Canopy and four in Reactor. Enlarging every jump beyond Roblox's physical range would make the course unfair; this revision widens smaller gaps while retaining measured flight margins.

| Sector | Main challenge | Alternate choice |
| --- | --- | --- |
| 1 · Split Steps | Staggered precision islands | Narrow approach and outer exit |
| 2 · Zigzag | 7×3.2 beams and visible outside hazard rails | Angled balance beams with optional sweeping-arm timing |
| 3 · Transfer | 6×6 shuttle travelling 18 studs | Static narrow bypass |
| 4 · Phase Shift | Two visibly warned disappearing pads | Static outer exit |
| 5 · Wall Walk | Narrow wall ledges and guarded beam | Angled inner route and outer exit |
| 6 · Crossing | Second moving transfer | Static narrow bypass |
| 7 · Tempo | Second pair of timed platforms | Precision approach and static outer exit |
| 8 · Final Ascent | Final islands and Updraft ascent | Precision approach and outer exit |

Every required Updraft rises 14 studs. An ordinary JumpPower52 jump has a theoretical 6.89-stud apex; Updraft speed88 has a 19.73-stud apex at gravity196.2. Walking speed is20. Lift receivers are P004/P012/P020/P028/P036/P044/P052/P060. Updraft launches retain a checked 25.7-stud overhead column. Cooldown is owned by shared Config.

## Finish contract

The previous whole-crown invisible trigger is removed. P064 now leads to a 24×20 crown landing apron with a six-stud horizontal gap. Players must then walk onto the clearly marked checker pad under the FINISH arch.

- Crown centre: `(0, 232, -23)`.
- `FinishPad`: an opaque collidable 12×0.2×5 surface, centre `(0, 232.1, -28.5)`, top Y232.2.
- `Finish`: an invisible 11×7×4 sensor, centre `(0, 235.7, -28.5)`. Its horizontal boundaries are inset 0.5 studs from the pad.
- `finish_walk_target`: `(0, 232.2, -28.5)` in exported metadata.
- The final approach, crown arrival point and crown centre are outside the sensor, including the old inflated 2.2-stud tolerance.
- Server finish validation additionally requires real grounded support on FinishPad. Flying past, crossing below, or landing short does not finish.

The checkerboard, arch and sensor refer to the same location. Native QA must traverse all 64 platforms, land on CrownDeck, then walk to `finish_walk_target`; it must not expect completion from P063/P064.

## Runtime geometry

Models `Helix`, `Canopy`, `Reactor` remain under `ServerStorage/Maps`; only one is active.

`Course/LaunchDeck`, `Course/P001`–`P064`, `Course/CrownDeck`, and branch models each contain a colliding `Walkable` with `CompletedStage`. Gates remain tied to P008/P016/.../P064. Ten distinct start markers face the first obstacle. Bounds remain centred at `(0,131,0)` with size152×286×152; the kill floor is Y−12.

Each tower lost416 enclosure pieces:192 opaque colliding wall panels,192 sector-rim segments,24 summit-rim segments and8 tall ribs. Remaining architecture is non-colliding. Detached pool/ring, foliage/planters, status lights and ledge panels were subsequently removed. Theme identity is carried by the actual platforms, their undersides and thin attached EdgeTrim strips. Functional Updraft diamonds/chevrons, shuttle guide rails, spawn marks and the finish arch remain. Course supports, moving paths, recovery ledges, hazards, Bounds and KillFloor did not move. There is no invisible replacement wall. All colliding map parts are now authored Walkable surfaces or FinishPad.

P018/P042 are shuttles with Travel magnitude18, Period8, Dwell1.2. P029/P030/P053/P054 are warned timed platforms with Period6.6, OnDuration4.8, WarningDuration1.1 and staggered phases. Two optional approach routes retain rotating hazard arms. Primary-route clearances are checked over the whole spinner sweep. Visible outside rails on P010/P038 remain real hazards; server contact logic uses the actual body footprint rather than a wide invisible margin.

## Authoring and checks

`tools/world.py` owns deterministic templates, orientation selection, metadata and geometry verification. `tools/lobby05.py` owns the unchanged lobby. `python tools/world.py` verifies without writing a place; `python tools/build.py` packages the world and refreshes `docs/map-metrics.json`.

The model has339 authored main/alternate transitions. Each is checked with a conservative upright avatar capsule along the ballistic jump at120 samples/second, including ground approach, landing exit, neighbouring sectors and moving-platform sweeps. Takeoff/landing hints are normal movement targets for QA, never teleport destinations. Updraft hints include a brief vertical lead so feet clear the higher receiving edge.

`python tools/test_route_clearance.py` covers six regression groups: every capsule corridor, the previously observed P022 head bump, the old shuttle overhang, true gaps and flight margins, absence of enclosing walls or colliding decoration, and the visible finish boundary. Existing native movement regressions remain necessary, and these geometry checks do not replace real players or unusual avatar testing.

Metadata also exports primary/alternate route graphs, transition distances, launch/landing hints, updraft requirements, movers, timed platforms, physical recovery paths, obstacle geometry, bounds, finish pad dimensions and finish walking target. Native results are recorded separately from generated-geometry checks.
