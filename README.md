# Oathbound

An open-world fantasy RPG on Roblox. The design lives in the Oathbound GDD v2; this repo is the playable prototype.

## Phase 1: combat arena

The first slice tests whether the combat feels good:

- **Three classes**, one per role, with the placeholder kits from the design docs:
  - **Assassin** (damage): basic attacks build combo points and apply Mark. Backstab, Poison Blade and Smoke Step. Hold left click at 5 points for the Finisher.
  - **Cleric** (healer): basic attacks heal the most hurt ally. Mend and Sanctuary.
  - **Warden** (tank): blocking builds Grit and Bulwark. Shield Bash interrupts, Cleave hits a cone, and Intercept (T) dashes to an ally and takes their next hit.
- **One-action timeline** on the server: wind-up, fire, recovery, in 50 ms ticks. Dodging cancels a wind-up and costs nothing.
- **Block, parry and dodge.** Attack colours tell you what works: white (anything), orange (dodge or parry), red (dodge or move).
- **The Ashen Sentinel**, a test boss with a white swing, an orange tank-buster, a red sweep and an interruptible cast. It also has a Break meter: parries and interrupts fill it, and a full meter stuns the boss for 3 seconds.
- **A training dummy** that measures your damage per second, shown as a multiple of Weapon Damage (the design's reference target is 4 x WD).

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

The boss is tuned for a group, so it will flatten one player. While playing, select **Workspace > Arena > Ashen Sentinel** and set its `DamageScale` attribute to something like `0.2`. To test with several players, use **Test > Clients and Servers** in Studio.

## Controls (PC)

| Input | Action |
|---|---|
| Left click (tap / hold) | Basic attack / heavy attack |
| Right click (hold) | Block. The first 200 ms is a parry |
| Space | Dodge roll (about 250 ms invulnerable) |
| Q, E, R | Skills |
| T | Signature key (Warden's Intercept) |
| F | Ultimate (not built yet) |
| 1, 2, 3 | Switch to Assassin, Cleric or Warden (out of combat) |
| Left Alt | Free the mouse |

The camera works like shift lock: your character faces where you look.

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
