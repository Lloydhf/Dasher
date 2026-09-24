# Dasher 0.2 environment notes

The race club lobby uses charcoal and navy architecture with restrained cyan and ivory light. Kiosks hold the labels in the world so the racing HUD can stay small. The atrium, seating, central halo and forward glass vista are assembled from editable Roblox parts. No imported toolbox models, plugins or executable art assets are required.

## Client integration

The following marker Parts are invisible, anchored and non-collidable. Build a camera transform with `CFrame.lookAt(marker.Position, CameraLookAt.Position)`; the marker's own rotation is not a camera direction.

| Path | World position |
| --- | --- |
| Workspace/Lobby/CameraStart | 22, 46, 133 |
| Workspace/Lobby/CameraEnd | -16, 34, 113 |
| Workspace/Lobby/CameraLookAt | 0, 28, 78 |
| Workspace/Lobby/SpawnLocation | 0, 22.5, 87 |
| Workspace/Lobby/Kiosks/Shop | -50, 30, 70 |
| Workspace/Lobby/Kiosks/Inventory | -50, 30, 108 |
| Workspace/Lobby/Kiosks/Quests | 50, 30, 70 |
| Workspace/Lobby/Kiosks/Leaderboard | 50, 30, 108 |

Kiosks are Parts with a SurfaceGui child and have no executable scripts. The client can attach local ProximityPrompts to these Parts to open the corresponding panels.

## Courses

| Map ID | Display name | Length (studs) | Part count |
| --- | --- | ---: | ---: |
| Skyline | CLOUDLINE | 1,181 | 1,003 |
| Neon | AFTERHOURS | 1,181 | 1,234 |
| Grid | THE GRID | 1,345 | 1,036 |
| Foundry | FOUNDRY | 1,181 | 991 |
| Zenith | ZENITH | 1,181 | 873 |

Every course has 74 primary landing decks, four optional gold dash forks and 24 consecutive `Gates/GateNN` triggers. The main line is deliberately dash-independent to support the longer cooldown. Its gaps are 3.5–5.5 studs. The four forks each require a 14.5-stud entry leap, followed by an ordinary 3.5-stud exit jump. A front-facing DASH label makes them readable without relying on color alone. They avoid forced cooldown waiting on narrow pads. A missed jump still resets the entire run.

Four six-section acts gradually narrow landings. Larger sector arches appear at 25%, 50% and 75%; other gates use quiet illuminated milestones. Decoration cannot create unintended shortcuts because only `Course/*/Walkable` decks collide. The Finish sits beyond the final deck center. `Bounds` describes an invisible box spanning the full route; `Hazards/KillFloor` covers the same footprint. The longest race extends to Z = -1,350 and must not be restricted by the old short-map bounds.

Five source maps are held in ServerStorage; the server should clone only the selected map into Workspace. The lobby has 230 parts. The most detailed live map plus lobby uses 1,464 parts before avatars/effects. Decks use seven parts apiece, and architecture is segmented at long intervals to avoid multiplying the old decorative instance cost.

## Verification and limits

- `world.py` compiled and `build_world()` generated all five maps successfully.
- Unique instance references, 390 colliding route decks, 120 ordered gates and all integration marker names were checked.
- Every normal edge-to-edge jump was checked against the ballistic envelope of WalkSpeed 22, JumpPower 52 and Gravity 196.2 with a two-stud horizontal margin. This is an analytical geometry check, not a substitute for real mobile and multiplayer playtesting.
- Shortcut entry and exit clearances, hidden markers and zero executable world assets were checked.
- Text uses official `Enum.Font.BuilderSansBold` value 48. Reference: https://create.roblox.com/docs/reference/engine/enums/Font

Tune routes after real playtests: the longer no-checkpoint races intentionally increase the cost of a fall. New maps should keep gold routes optional, preserve room for cooldown recovery and avoid relying on cosmetics for collision cues.
