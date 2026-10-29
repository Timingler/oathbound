# Placeholder values

Every number in this prototype is a placeholder until playtests say otherwise. Most come from the design docs and are marked `[A]` there. This file lists the ones the docs **did not** give, which I chose so the arena would run. They are marked `[Proto]` in the code.

None of these have been playtested.

## Combat

| Value | Where | Why it was needed |
|---|---|---|
| Dodge cooldown 0.8 s | `Constants.DODGE_COOLDOWN` | The GDD gives dodge invulnerability (about 250 ms) but no cooldown or cost, so dodge could be spammed for permanent invulnerability. |
| Damage layers combine multiplicatively, then cap at 80% | `Formulas.totalDR` | The GDD gives the caps for passive, block, external and total DR, but not how the layers combine. |
| Healing threat 0.5x | `Constants.HEAL_THREAT_MULT` | The GDD says tanks generate 3x threat but says nothing about healing threat. |
| Range slack 4 studs | `server/Abilities.luau` | Gives some room for latency until position rewind exists. |
| Heavy attack hold time 0.25 s | `client/Input.luau` | The GDD says "hold" for heavy attack without a time. |
| Dodge roll speed 55 studs/s for 0.3 s | `client/Input.luau` | Feel value only. |
| Player level 50, item level 65 | `CombatService` | The arena runs at the GDD's tier 1 reference point, so WD is 512. |

## Kits

| Value | Where | Why it was needed |
|---|---|---|
| Mark lasts 10 s | `Kits/Assassin.luau` | The kit says basic attacks apply Mark, with no duration. |
| Smoke Step usable during a dodge or up to 0.35 s after | `Kits/Assassin.luau` | The kit says "1.0 s untargetable after a dodge" but not how it is triggered. |
| Heal range 40 studs | `Kits/Cleric.luau` | Not in the kit table. |
| Sanctuary radius 21 studs | `Kits/Cleric.luau` | The kit says 6 m; 1 stud is about 0.28 m. |
| Cleave cone 120 degrees, range 12 | `Kits/Warden.luau` | The kit says "frontal" only. |
| Intercept range 40 studs, targets the lowest-HP ally, guard waits 4 s | `Kits/Warden.luau` | The kit says "dash to an ally and take the next hit" only. |
| Everyone can block and parry, with the Warden's Stamina numbers | `Constants` | The GDD controls give block and parry to every class, but only the Warden kit lists Stamina. |

## Boss (Ashen Sentinel)

The attack pattern and hit sizes come from encounters E4 and E6 in the Build System Review. These parts are mine:

| Value | Why it was needed |
|---|---|
| 600,000 HP | Aims at the GDD's 2 to 4 minute dungeon boss with about three players. |
| Wind-ups: swing 0.8 s, buster 1.2 s, sweep 1.5 s | The GDD only says group wind-ups are at least 600 ms. |
| Cone 14 studs and 100 degrees, sweep radius 18 studs | Shapes were not specified. |
| Break meter 100, parry +15, interrupt +30 | The GDD wants a 15 to 29 s fill time but gives no per-action values. |
| Enrage doubles damage | The GDD gives the 10 minute enrage timer but not what it does. |
| Moves at 12 studs/s, aggro 45, leash 90, resets after 8 s alone, respawns after 15 s | Arena behaviour only. |

## Left out on purpose

These are in the design but have no defined values yet, so they are not built. I did not invent them.

- Ultimates (no ultimate is designed for these three classes)
- Mastery (no per-class effect is designed)
- Cleric's Divine Grace and cleanses (cleanse effects are undefined)
- Talents, gear and item modifiers (Phase 2)
- Revive charges and downed state (Phase 1 respawns you instead)
- Position rewind for latency (the server checks range with slack instead)
