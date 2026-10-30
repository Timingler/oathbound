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
| Smite (Cleric basic) 0.55 damage, 0.35 heal | `Kits/Cleric.luau` | The kit table's basic only healed, so a Cleric had no damage. |
| Sanctuary radius 21 studs | `Kits/Cleric.luau` | The kit says 6 m; 1 stud is about 0.28 m. |
| Cleave cone 120 degrees, range 12 | `Kits/Warden.luau` | The kit says "frontal" only. |
| Intercept range 40 studs, targets the lowest-HP ally, guard waits 4 s | `Kits/Warden.luau` | The kit says "dash to an ally and take the next hit" only. |
| Everyone can block and parry, with the Warden's Stamina numbers | `Constants` | The GDD controls give block and parry to every class, but only the Warden kit lists Stamina. |
| The whole Ranger kit: Focus 100, +12/s, +4 per Quick Shot; Quick Shot 0.7 coeff, 0.35 s wind-up, 140 studs/s; Aimed Shot 2.2, 0.9 s, 220 studs/s, 15 Focus; Piercing Arrow 1.6, 8 s, 25 Focus; Volley 1.1 in a 10-stud circle, lands 0.6 s after release, 14 s, 35 Focus; Disengage 22 studs back, 0.3 s untouchable, 12 s | `Kits/Ranger.luau` | The Ranger (base class for Marksman, Beastmaster and Druid) is not in the placeholder kit table yet. |
| Arrow drop 30 studs/s², reach 1.3x range, hit radius +1 stud | `server/Projectiles.luau` | Feel values; arrows lead their target for the drop. |

## Animation feel

| Value | Where | Why it was needed |
|---|---|---|
| Combat animations play at 0.75x to 1x, strike timed to the hit | `server/Animations.luau` | Playtest feedback: squeezing whole animations into short actions looked rushed. |
| Hit-stop 0.06 s, 0.11 s on crits and slow attacks | `server/Animations.luau` | Feel value: the swing pauses as it connects. |
| Flinch at 1.2x, skipped mid-swing or while blocking | `server/Animations.luau` | A flinch must not cut an attack whose hit still lands. |
| Camera shake 0.25 degrees on heavy hits dealt, 0.6 on hits over 15% of your HP | `client/Effects.luau` | Feel value. |
| Walk cycle matched to 14.5 studs/s (about 1.1x at walk speed 16) | `client/Locomotion.luau` | Playtest feedback: 1.33x looked hurried. |

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
- Talents (Phase 2). Gear is in as a test bag; see Inventory below.
- Revive charges and downed state (Phase 1 respawns you instead)
- Position rewind for latency (the server checks range with slack instead)

## Animation

| Value | Where | Why it was needed |
|---|---|---|
| Run animation from 20 studs/s, 0.2 s fades | `client/Locomotion.luau` | The prototype has no sprint yet, so at the default 16 studs/s the walk cycle plays. |
| Combat animations stretched over wind-up + recovery, rate 0.5x to 3x; combo resets after 1.5 s | `server/Animations.luau` | The source animations have their own lengths; this keeps them in step with the timeline. |
| Roll animation at 2x speed | `client/Input.luau` | The roll is 1.17 s long and the dodge lasts 0.3 s. |

## Inventory

| Value | Where | Why it was needed |
|---|---|---|
| Rarity ladder Common 0 to Legendary 4 modifiers, Unique 4 + an effect (effect text only, not simulated) | `shared/Items.luau` | GDD v2 gives the ladder but no stat ranges. |
| Modifier rolls 100 to 260 rating at item level 65, +2% per item level | `shared/Items.luau`, `server/Inventory.luau` | K is about 1,182 at level 50, so one modifier is roughly 10 to 20% of a stat's ceiling. |
| Starter set: Common iL 65 in all 9 slots; bag of 18 random items, iL 60 to 72, one of each rarity guaranteed | `server/Inventory.luau` | Something to try on. Not saved between sessions. |
| Item level = average of the 9 slots, empty slots count as 65 | `server/Inventory.luau` | Drives WD and HP through the existing formulas. |
| No gear swaps until 5 s after the last hit | `server/Inventory.luau` | Same rule as switching class. |
