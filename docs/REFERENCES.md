# Ascent v0.5 — reference review

Reviewed 23 September 2026. The videos were opened in a browser and sampled visually; they were not watched in full. No models, maps, music, animation files or branding were copied.

- [MathFacter360 — How I Beat Roblox's Longest Tower](https://www.youtube.com/watch?v=4b_C8WTLHBY): sampled around 6:03, 15:09 and 24:15. Small disconnected stepping cubes, visible hazard borders, sector resting ledges and readable color changes informed the new precision sections.
- [PinkLeaf — Tips & Tricks in Tower Of Hell 2.0](https://www.youtube.com/watch?v=CDtUw0lAbTc): sampled around 4:10 and 7:18. Narrow angled planks and wall-side traversal informed the balance and ledge sections. These samples do not establish every obstacle's motion or timing.
- [HeartyASMR — Tower of Hell keyboard gameplay](https://www.youtube.com/watch?v=GJNkGVGoLaU): sampled around 2:18 and 3:51. The sparse timer, small level bar, layered colored routes and bright environmental obstacles informed the quieter HUD and clear hazard vocabulary.
- [Tower of Hell official experience](https://www.roblox.com/games/1962086868/Tower-of-Hell): genre reference. Dasher retains its own routes and one limited Updraft.

## Implementation references

- [Roblox moving objects](https://create.roblox.com/docs/tutorials/use-case-tutorials/physics/create-moving-objects): movement and physics considerations. Ascent uses deterministic anchored shuttle motion and verifies riders explicitly; it does not assume an animated anchored part automatically carries characters.
- [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters): lifetime, rate and acceleration support small movement-only cosmetic effects.
- [Font enumeration](https://create.roblox.com/docs/reference/engine/enums/Font): v0.5 restores Nunito (35) and FredokaOne (26) instead of the v0.4 Arimo pair. Verified against the official creator-docs enum source on 24 September 2026.
- [ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt): authored lobby NPC prompts open the existing Shop, Inventory, Quests and Leaderboard pages.

## Design decisions

Difficulty comes from precision, boarding windows, disappearing footholds and environmental timing. Updraft provides an intentional route tool and an occasional recovery opportunity. Players cannot hit, push or body-block each other. Recovery ledges are terrain, not saved checkpoints. Stage currency and XP can be claimed once per sector per round, including after a restart. These are design choices to playtest, not evidence of retention or commercial success.
