# Dasher Ascent — v0.5 tower routes

The three towers now offer route choice within every sector. Their regular jumps have visible gaps, narrow landing faces and a useful running approach. A main route and a separate precision bypass meet at each Updraft launch. Six sectors also have an outer route after the lift; the two moving-platform sectors offer a static, narrow alternative to waiting for the carrier.

## Layout and difficulty

Each tower has eight 26-stud sectors, 64 numbered primary platforms, 34 separate alternate platforms, a launch deck, a crown and eight physical recovery ledges. Start surface Y22, final surface Y232: 210 studs of ascent. There are fourteen explicit branch choices per tower. Paths are choices within one shared race, not separate checkpoint courses.

| Course | Primary normal edge gaps | Main parts | Character |
| --- | --- | --- | --- |
| Helix | 3.77–8.0 studs | 538 | Suspended orbital structure; looping diagonal routes and broken outer rings |
| Canopy | 3.61–8.5 studs | 541 | Asymmetric woodland turns, timber supports, tree crowns and hanging vines |
| Reactor | 4.0–8.6 studs | 515 | Angular industrial crossings, cooling spines and restrained status lighting |

These are true oriented surface-edge distances. Most ordinary landings are 4.8–6 studs wide; balance beams have a 3.2-stud narrow dimension. The 24×18 launch accommodates ten separate spawn markers. Shared rests are 14×14 and lift launch/receiver pads are 10×10. Large comfortable receivers no longer make the surrounding jumps trivial.

| Sector | Main challenge | Alternate choice |
| --- | --- | --- |
| 1 · Split Steps | Staggered precision cubes | Shorter narrow approach, outer exit |
| 2 · Crossbeams | 7×3.2 beams and lethal outside rails | Precision approach with an outside sweeping arm; outer exit |
| 3 · Transfer | 6×6 shuttle travelling 18 studs | Static narrow bypass, avoiding the wait |
| 4 · Phase Shift | Two warned disappearing pads | Static outer exit at the cost of precise landings |
| 5 · Skyline | Narrow ledges and guarded beam | Inner precision approach, outer exit |
| 6 · Crossing | A second moving transfer higher in the tower | Static narrow bypass |
| 7 · Tempo | Second pair of timed platforms | Precision approach and outer exit |
| 8 · Final Ascent | Small final cubes and a last lift | Separate precision approach and outer exit |

Each required Updraft transition rises **14 studs**, beyond the 6.89-stud apex of an ordinary JumpPower52 jump. Lift receivers are P004, P012, P020, P028, P036, P044, P052 and P060. Lift launches have a checked 25.7-stud overhead column. Updraft speed88 has a theoretical 19.73-stud apex; ordinary walking speed is20 with gravity196.2. Cooldown is owned by shared Config, not by map geometry.

The crown is an obvious 24×20 plaza with a FINISH arch and checkered stripe. The finish sensor covers the whole plaza. A player never has to find a tiny hidden finish point. Falling onto a lower genuine platform is allowed; catch ledges sit two studs below lift receivers and have a normal jump back. There are no checkpoint teleports.

## Runtime contract

Maps remain Models `Helix`, `Canopy`, `Reactor` under `ServerStorage/Maps`. One is active at a time.

- `Course/LaunchDeck`, `Course/P001`–`P064`, `Course/CrownDeck` and `Course/B01_01` etc. are platform Models. A colliding `Walkable` owns an `IntValue` named `CompletedStage`.
- `CompletedStage` is sector−1 on traversal/alternate platforms, sector on its completed rest, and8 on the crown. It is progress metadata; it does not move the player. Grounded contact with legitimate higher sections can advance past a missed exact rest.
- `Gates/Gate01`–`Gate08` remain at rest top+2, size14×6×14. Their `Landing` StringValue names P008, P016, … P064. Gate Y values are50,76,102,128,154,180,206,232.
- `Start` is(0,26,0). `Start01`–`Start10` are ten root-level markers at Y26, X−8/−4/0/4/8 in rows Z−4/+4, facing the first obstacle.
- `Finish` is at crown center X/Z, Y237, size24×12×20. Crown surface Y232. Its position is taken from generated metadata instead of assuming a fixed X/Z.
- `Bounds` center(0,131,0), size152×286×152. Kill floor is Y−12. Environmental artwork is non-colliding.
- `CatchLedges/Catch01`–`Catch08` have explicit CompletedStage and a physical ordinary-jump rejoin.

### Moving surfaces and timing

`Course/P018` and `P042` contain Motion=Shuttle, Travel Vector3 of magnitude18, Period8, Dwell1.2, Phase0. The far dock is needed to leave the main path; the static branch is a legitimate alternative. `CourseMotion` moves the whole platform Model, and verified carrying uses the actual authored motion.

P029/P030/P053/P054 contain Motion=Blink, Period6.6, OnDuration4.8, WarningDuration1.1. Adjacent phases differ by0.65. Main players can wait on the preceding stable lift receiver. Outer precision branches do not disappear.

Two optional approach routes have 16-stud rotating hazard arms at angular speed0.8. The authored full sweep stays more than10 studs from primary-route footprints at comparable height. Their outside sweep clips a shortcut edge, leaving a narrow safe line. Red outside rails on P010 and P038 are real lethal geometry.

## Authoring and verification

`tools/world.py` contains the authored templates, deterministic orientation selection, exported metadata and geometry checks. `tools/lobby05.py` separately owns the lobby. A direct `python tools/world.py` checks the whole world without creating a place; `python tools/build.py` writes the place and refreshes `docs/map-metrics.json`.

Checks include all primary and alternate route transitions, actual oriented rectangle gaps, normal/Updraft ballistic range, safe takeoff/landing hints, headroom across adjacent sectors, recovery jumps, movement dock endpoints, distinct branch surfaces, spinner clearance, stage metadata, map bounds, part budgets and unique XML referents. These checks establish geometric feasibility; native Studio playtests and real players remain necessary for movement feel and difficulty balance.

`COURSE_METADATA[theme]` exports:

- `primary`/`route`: 66 shared and numbered primary surfaces.
- `alternates`: 34 independently positioned branch surfaces.
- `branches`: eight sectors, each with a `main` chain and `alternatives` containing `chain`, `bypasses` and `transitions`.
- `transitions`: normal/updraft type, rise, edge gap, ballistic flight/range, margin, and world `takeoff`/`landing` positions inset into the support.
- `required_updrafts`, `movers`, `timed_platforms`, `gates`, `catch_ledges`, `obstacles`, `bounds`, `difficulty`.

The takeoff/landing hints are for QA navigation, not in-game teleporting. They account for the safe centre lane between lethal beam rails. Testing all jumps from each platform's center would wrongly characterize deliberately challenging running jumps as impossible.

### Avatar clearance regression checks

The centre-only overhead check was insufficient: native play identified a head bump from Helix P022 toward P023 under B04_02. Every authored transition now additionally checks a 1-stud-radius, 5.5-stud-high upright capsule at120 samples/second along its ballistic path, plus the grounded walk from the platform centre to takeoff and from landing back to centre. This checks339 primary/alternate transitions across the three towers. Moving slabs above a jump are checked across their swept travel.

Helix P022→P023 uses a clear departure lane on the side of its existing platform. Helix sector6 was turned90 degrees so its carrier no longer sweeps an unrelated lower jump's headroom. Other tower geometry is unchanged by this correction. Updraft metadata includes a short vertical lead before horizontal movement, allowing feet to clear the higher receiver before crossing its edge.

`python tools/test_route_clearance.py` exercises the339 corridor assertions and explicitly reproduces both old obstructed layouts, requiring the repaired lanes/layout to pass. This conservative default-avatar model does not replace native testing of unusual avatar body packages.
