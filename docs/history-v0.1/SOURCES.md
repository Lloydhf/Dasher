# Implementation references

Checked during development on 2026-09-16. Primary documentation is used for API behavior; balance, art direction and interface decisions are project choices.

- Roblox — [LinearVelocity](https://create.roblox.com/docs/reference/engine/classes/LinearVelocity)
- Roblox — [Blockcast](https://create.roblox.com/docs/reference/engine/classes/WorldRoot/Blockcast)
- Roblox — [Motor6D](https://create.roblox.com/docs/reference/engine/classes/Motor6D)
- Roblox — [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)
- Roblox — [Data stores](https://create.roblox.com/docs/cloud-services/data-stores)
- Roblox — [Client/server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary)
- Roblox — [Network ownership and movement validation](https://create.roblox.com/docs/scripting/security/network-ownership)
- Roblox — [Create animations](https://create.roblox.com/docs/tutorials/use-case-tutorials/animation/create-an-animation)
- Roblox — [Performance optimization](https://create.roblox.com/docs/performance-optimization)
- Roblox — [Current lighting style and quality settings](https://create.roblox.com/docs/environment/lighting)
- Rojo — [Build a Roblox place](https://github.com/rojo-rbx/rojo.space/blob/master/docs/getting-started/new-game.mdx)

## Tool decisions

The connected plugin directory was searched for Roblox/Blender integrations; no matching installable integration was returned. Studio's existing tools and a deterministic local XML builder are sufficient for this deliverable. No unreviewed Toolbox code or third-party Studio plugins are installed. Rojo remains an optional future workflow, not a dependency needed to open this project.

Dash pose overlays are procedural and support the avatar rigs explicitly handled by the client. They are not claimed to be a separately authored/uploaded animation asset. Asset-based animation can replace them later without changing the game rules.
