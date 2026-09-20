# Dasher Next — design decisions, 17 September 2026

## Direction

Build a repeatable competitive game with a readable first minute. The lobby introduces voting and cosmetics without covering the race view in permanent panels. A small persistent HUD is separate from the deliberately larger menu a player opens voluntarily.

Extending the dash cooldown without changing routes would create waiting rather than skill; the main route therefore uses ordinary jumps and four optional forks per map give dash a purpose. Long routes provide an endurance challenge. If first-course completion is too low, shorten a rotation variant before adding paid skips or forcing more grind.

Only one course is active at a time. Native parts avoid external executable models. Restrained bloom and a consistent visual vocabulary replace imported effects. Camera sequences have a recovery path and reduced-motion support.

## Economy

First place pays 20 coins rather than 60. Other finishers receive 14, with small podium bonuses. The first purchasable trail is 120 coins: six first-place finishes before daily/weekly rewards. Ten finishes earn a claimable 80-coin weekly bonus. Daily claims grant 25, without a streak penalty. These are starting values to measure, not established optimal retention numbers.

Weekly ranking rewards completed races. XP never improves jump height, dash recharge or speed. Cosmetics do not change physics. Spectating before finishing forfeits the run to prevent rejoin/reward abuse.

## Research used

Official descriptions of [Tower of Hell](https://www.roblox.com/games/1962086868/Tower-of-Hell), [Speed Run 4](https://www.roblox.com/games/183364845/Speed-Run-4), and [PARKOUR Reborn](https://www.roblox.com/games/11639495622/PARKOUR-Reborn) informed checkpoint-free retrying, varied course settings and movement mastery. These pages were reviewed; the games were not exhaustively played or benchmarked. No assets or source were copied.

Roblox's [retention guidance](https://create.roblox.com/docs/production/analytics/retention) emphasizes the early core loop, understandable objectives, progression and continuing content. [Engagement guidance](https://create.roblox.com/docs/production/analytics/engagement) supports examining session behavior and performance. This iteration focuses on playability before expanding monetization. These documents do not establish that a specific feature will improve Dasher's retention.

[Developer product documentation](https://create.roblox.com/docs/production/monetization/developer-products) places purchase fulfilment in the server receipt flow. Product IDs remain zero and commerce stays off until durable, repeat-safe grants and live tests exist.

## Next iteration gates

1. Observe at least five new players: understanding voting/dash, first finish, resets, voluntary second race and camera comfort.
2. Test two to four clients: simultaneous finishes, a spectator target leaving, changed votes, joining mid-race and reconnecting saved profiles.
3. Test touch and gamepad on real devices, including frame rate and long-course visibility.
4. Tune course length and rewards from observations. Keep primary routes independent of dash availability.
5. Define unfinished runs, disconnects and uneven-team scoring before adding teams. Set up products and receipt tests before commerce.

Season content should initially mean a small route or cosmetic update. No expiring paid track, artificial purchase timer or social notification spam is implemented.
