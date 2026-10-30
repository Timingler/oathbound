# Oathbound

An open-world fantasy RPG on Roblox. The design lives in the Oathbound GDD v2; this repo is the playable prototype.

## Phase 1: combat arena

The first slice tests whether the combat feels good:

- **Four classes** with the placeholder kits from the design docs (the Ranger is a prototype addition):
  - **Assassin** (damage): basic attacks build combo points and apply Mark. Backstab, Poison Blade and Smoke Step. Hold left click at 5 points for the Finisher.
  - **Cleric** (healer): basic attacks heal the most hurt ally. Mend and Sanctuary.
  - **Warden** (tank): blocking builds Grit and Bulwark. Shield Bash interrupts, Cleave hits a cone, and Intercept (T) dashes to an ally and takes their next hit.
  - **Ranger** (ranged damage, key 4): a skill class with real arrows and no auto-aim: hold right click to aim (zoom, draw), left click to loose. The longer the draw, the harder and faster the arrow; arrows drop slightly and take time to arrive. Quick Shot (left click without aiming), Aimed Shot (left click while aiming), Piercing Arrow, Volley (arrows rain on a circle) and Disengage (leap back). The base class for Marksman, Beastmaster and Druid later. Bow, animations and sounds from the Bow & Arrow System kit.
- **One-action timeline** on the server: wind-up, fire, recovery, in 50 ms ticks. Dodging cancels a wind-up and costs nothing.
- **Block, parry and dodge.** Attack colours tell you what works: white (anything), orange (dodge or parry), red (dodge or move).
- **The Ashen Sentinel**, a giant hammer knight in its own ring at the far end of the arena; step inside the ring to start the fight. Every attack is drawn on the floor and fills up before it lands: a 3-swing white Cleave, an orange Sundering Blow, an Ash Leap onto the farthest player, an Ash Sweep and an interruptible Doom Chant. Below 60% HP it catches fire and adds the Cinder Ring (stand close) and Ember Lines (stand between the lines). Hits never flinch it; only its Break meter does: parries and interrupts fill it, and a full meter stuns it for 3 seconds.
- **Poise**: enemies only flinch when their poise breaks, and are then stagger immune for 5 seconds, so a group cannot stun-lock them.
- **The Hollow Duelist**, an animated R6 swordsman with AI (`server/Duelist.luau`), to the right of the spawn. It walks to you and swings telegraphed combos: white-outlined slashes (block, parry or dodge) and, every third combo, a slow orange-outlined thrust (parry or dodge). It blocks some of your attacks from the front, rolls away when you pile on hits, and is staggered for 1.2 seconds when you parry it. When it dies, a new one steps up after 8 seconds.
- **A training dummy** to the left of the spawn that measures your damage per second, shown as a multiple of Weapon Damage (the design's reference target is 4 x WD). It is an R6 figure that turns to face you but never fights back.

Every number is a placeholder. The values the design docs did not give are listed in [docs/PLACEHOLDERS.md](docs/PLACEHOLDERS.md). **Nothing here has been playtested yet.**

## Running it

You need [Roblox Studio](https://create.roblox.com/) and [Rokit](https://github.com/rojo-rbx/rokit) (which installs Rojo, Lune, StyLua and Selene at the versions in `rokit.toml`).

```sh
rokit install          # once
rojo plugin install    # once, installs the Rojo plugin into Studio
rojo serve             # then connect from the Rojo plugin in Studio
```

1. In Studio, create a new Baseplate place.
2. Run `rojo serve` in this folder and press **Connect** in the plugin.
3. Press **Play**. The arena builds itself when the server starts.

Every character spawns as R6 (`server/ForceR6.luau`), because the animations are R6 only. Publish the place to your own account first: animations only play in places owned by the account that uploaded them.

To build a place file without Studio running: `rojo build -o oathbound.rbxl`.

### Testing alone

The boss is tuned for a group, so it will flatten one player. While playing, select **Workspace > Ashen Sentinel** and set its `DamageScale` attribute to something like `0.2`. Set its `SetHealth` attribute to `0.55` to jump straight to phase 2. To test with several players, use **Test > Clients and Servers** in Studio.

## Controls (PC)

| Input | Action |
|---|---|
| Left click (tap / hold) | Basic attack / heavy attack |
| Right click (hold) | Block. The first 200 ms is a parry. Ranger: aim |
| Space | Dodge roll (about 250 ms invulnerable) |
| Q, E, R | Skills |
| T | Signature key (Warden's Intercept) |
| F | Ultimate (not built yet) |
| F1 to F4 | Switch to Assassin, Cleric, Warden or Ranger (out of combat) |
| 1 to 5 | Hotbar: take out what is in that slot (your weapon, or a tool like the pickaxe or torch). Press a tool's key again to put it away; skills draw the weapon on their own |
| Left Shift or Left Ctrl | Toggle camera lock (off by default): hides the cursor and turns you with the camera |
| I or Tab | Inventory: hover an item to compare (the piece glows on your character), click to equip, right-drag to turn the view. Gear shows on your character; weapons and off-hands are per class. Hover a weapon or tool and press 1 to 5 to put it on the hotbar; right-click a hotbar slot to empty it |

With camera lock on, your character faces where you look; with it off, it faces where it moves.

## Tests

The shared formulas (scaling, armor, stat curve, caps, the action timeline and kit data) have unit tests that run outside Roblox:

```sh
lune run tests/run
```

The tests check the formulas against the tables in the GDD, for example WD 512.2 at level 50 / item level 65, and 15 / 25 / 35% armor DR at every level.

## Layout

```
src/shared/    Pure modules, used by server, client and tests
  Constants    Timeline, defense, caps and boss rules
  Scaling      F, G, Weapon Damage, HP and armor
  StatCurve    The secondary stat curve
  Formulas     Crits, cooldowns, costs, DR stacking, shields and heals
  Timeline     The one-action state machine
  Kits/        Assassin, Cleric and Warden ability data
  Net          Remote names
src/server/    Combat loop, abilities, boss AI and arena
src/client/    Input and HUD
tests/         Lune test runner and specs
docs/          Placeholder register
```

## What comes next

Still to do in Phase 1, from the GDD roadmap:

- Attack animations and hit effects (the prototype has floating numbers only; walk, run and idle use the R6 Run System kit, see [docs/ASSETS.md](docs/ASSETS.md))
- Position rewind, so the server judges hits where players were when they acted
- Downed state and revive charges in place of respawning
- Comparing the signature control schemes A, B and C
- Measuring parry success at 150 ms against 30 ms ping
- Logging fights to check the simulators within 3%
