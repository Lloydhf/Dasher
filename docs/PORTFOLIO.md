# DASHER — portfolio case study

## Design problem

A parkour race needs readable movement choices, meaningful retries and a fair comparison between players. DASHER explores those decisions through five courses with start-only resets and optional dash shortcuts.

## Decisions visible in the current source

| Decision | Intended effect | Tradeoff to test |
| --- | --- | --- |
| Main routes work with ordinary jumps; dash creates optional forks | Keep baseline progress accessible while rewarding timing | Players may not discover or value the forks |
| A fall resets the run to the start | Make clean execution matter | Late failures may discourage a new player |
| Earned cosmetics do not change movement | Keep competition independent of cosmetic ownership | Rewards must remain appealing without power increases |
| Voluntary spectating forfeits an unfinished race | Avoid leaving and rejoining to bypass race rules | The consequence must be clear before switching |

These are design intentions, not measured player outcomes. Read [NEXT-DESIGN.md](NEXT-DESIGN.md) for tuning rationale and [TESTING.md](TESTING.md) for the boundaries of previous verification.

## How to inspect

Play one course, try a normal route and a dash fork, then inspect `src/shared/Config.luau`. Compare the failure cost and reward values with the intended experience. The source builder creates editable Roblox parts, making geometry review possible inside Studio.

## Evidence still needed

Add a short unedited gameplay recording, observations from new players, before/after images of one route revision, and Kuzey's own explanation of the tradeoff. Automated traversal confirms feasibility under its test conditions; it is not evidence of enjoyment or beginner accessibility.

## Authorship

Project direction: Kuzey (Lloydhf). Implementation, build tooling and documentation include OpenAI Codex assistance. Existing verification notes describe earlier work and retain their dates. This publication update does not invent new playtests or claim independent authorship of generated code.
