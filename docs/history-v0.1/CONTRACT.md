# Dasher integration contract

First release: three hand-authored maps, restart at map start on any fall, own avatars, one dash, fair cosmetic-only coins. No paid products. Runtime English, documentation Turkish + English.

## Instances
- ReplicatedStorage/Dasher/Config (ModuleScript shared configuration)
- ReplicatedStorage/Dasher/Remotes/{Action,State,Feedback,DashFX} (RemoteEvents created by server)
- ServerScriptService/DasherServer (Script), sibling ProfileStore (ModuleScript)
- StarterPlayer/StarterPlayerScripts/DasherClient (LocalScript)
- ServerStorage/Maps/{Skyline,Neon,Grid} (Model templates)
- Workspace/Lobby with SpawnLocation at (0,25,85), floor top y22.
- Active map cloned into Workspace/ActiveMap. All maps run toward negative Z. Start point approx (0,28,0). Walkable platform top y22..29. Kill plane y3. Finish approx z-360..-440.
- Each map: Start (noncollidable invisible part, spawn CFrame looking -Z), Finish (noncollidable trigger volume), Gates folder with invisible sequential Gate01..Gate08 parts, Hazards folder with kill floor/lethal geometry. Respawn NEVER uses gates; they only validate sequential progress.
- Decorative parts have CanCollide=false. Walkable parts anchored. Map Config records Start/Finish positions read from instances, theme data in Config.Maps.

## Config
Config.WalkSpeed=22; JumpPower=52; DashSpeed=82; DashDuration=0.20; DashCooldown=1.15; RoundDuration=240; Intermission=12; Countdown=4; ResultsDuration=10; SpeedMultiplier=1.5; FinishReward=40; RankBonuses={20,10,5}; MapOrder={"Skyline","Neon","Grid"}.
Config.Maps keyed by ids: name, subtitle, accent(Color3), clockTime, ambient(Color3), outdoorAmbient(Color3), fogColor(Color3), fogStart, fogEnd.
Config.Cosmetics array {id,name,price,color(Color3)}, ids ice(default free),solar(120),orchid(240),mint(360). Cosmetic trail only.

## Network
Action client->server (action:string,payload:any): "Ready" (request snapshot), "Dash" (Vector3 horizontal direction), "Restart", "Accelerate", "Buy" (cosmetic id), "Equip" (cosmetic id).
DashFX server->all (player:Player,direction:Vector3): confirmed dash; client predicts ONLY its own movement immediately, FX for other characters rendered on confirmation; server validates cooldown/state/direction and sets Player attribute DashAt to server time. Server also independently clamps dash displacement and validates gates.
Feedback server->client (kind:string,message:string,extra:any): Toast,Finish,Reset,Purchase,Error,DashDenied. DashDenied must stop predicted dash.
State server->client snapshot table: phase("Waiting","Intermission","Countdown","Racing","Results"),mapId,mapName,roundId,timeLeft,multiplier,finishers(array {userId,name,time,coins}),racing(bool for recipient),finished(bool),canAccelerate(bool),runStartedAt(server time),coins,owned(dictionary id=true),equipped,progress(0..1),best(number seconds or nil),saveStatus("saved","session","loading","error"). server sends per player ~4Hz or on changes. Time sampled at workspace:GetServerTimeNow(). runStartedAt remains unchanged on fall/restart, starts per joining entrant. Can join underway round, timers personal. "Racing" active controls except finished. All-finished excludes disconnected/inactive entrants.

## Player attributes
DashAt:number, IsRacing:boolean, EquippedTrail:string. Others optional. UI reads State. Round roster and coin rewards server-owned. Client never supplies finish/time/reward.

## Studio tests
Keep server modules separable. DataStore disabled/unpublished gracefully uses session data; never overwrite persisted data after failed load. Runtime must work in unpublished Play Solo without HTTP or API-services setting changes. Optional workspace attribute DasherTestMode enables accelerated test timing ONLY when RunService:IsStudio(). No production bypass.
