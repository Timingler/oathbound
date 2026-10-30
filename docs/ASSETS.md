# Assets

An animation only plays in a game owned by the account (or group) that uploaded it. A foreign ID loads as an empty track that never ends, so animations from other people's places look broken or hang scripts. Every ID in `src/shared/AssetIds.luau` was uploaded to the Oathbound account (user 102707091) through Open Cloud on 2026-10-30.

## Where they came from

The movement, wall run, climb and bow animations come from four free Creator Store kits. The combat animations come from the **vania** place, which Charles says was released for reuse. All of them were re-uploaded from the KeyframeSequences the files ship in their `AnimSaves` folders. Quirkbound was not used: its scripts show it was copied from the live game with an exploit.

| Kit | Rig | Animations | Used in the prototype |
|---|---|---|---|
| Advanced R6 Run System (@skaterstudios) | R6 | Idle, walk and run in 4 directions | Yes, `client/Locomotion.luau` |
| R6 Wall Run (@skaterstudios) | R6 | Wall run and wall jump, left and right | Not yet |
| Advanced R15 Wall Climb System | R15 | Climb in 4 directions, climb idle, ledge hold/shimmy, vault | Not yet |
| Bow & Arrow System | R6 | Bow idle, run, aim, aim hold, aimed shot, shoot, plus 5 sounds | Not yet (for the Ranger) |
| vania | R6 | Sword, dagger and hammer combos, block, parry, roll and skills (24, listed below) | Yes, `server/Animations.luau` and the dodge in `client/Input.luau` |

### Combat animations (vania)

| Class | Basic attack (4-hit combo) | Abilities | Block |
|---|---|---|---|
| Warden | One-hand sword M1 to M4 | Shield Bash: Hilt Pommel. Cleave: sword skill 2. Intercept: Striking Advance | Sword block |
| Assassin | Dagger 1 to 4 | Finisher: dagger skill 4. Backstab: assassination. Poison Blade: dagger skill 1 | Dagger block |
| Cleric | Hammer 1 to 4 | Sanctuary: slam the ground. Mend: "Healing" from REFramework | Sword block |
| Everyone | | Parry: parry 1 and 2, alternating. Dodge: roll | |

The server plays each one when the action goes on the timeline, stretched over its wind-up plus recovery. The Hollow Duelist plays the Warden's set the same way, plus the walk, idle and roll animations. The boss is built from parts, so it is not animated.

### Weapons

`server/Weapons.luau` puts vania's weapon models in each class's right hand: the Mika sword (Warden), Long Dagger (Assassin) and Great Hammer (Cleric). The animations were made on vania's rig, which moves a `Hilt` part joined to the Right Arm, so the weapon is welded to a Hilt joined the same way. `tools/reupload/weapons.py` generates `src/shared/WeaponLibrary.luau`. The Mika sword uses a SurfaceAppearance in vania, which scripts cannot copy, so it shows plain colours here.

Like vania's WeaponHandler, the server loops a hold pose while the weapon is out, so the arm grips it between attacks (`AssetIds.Hold`). The poses are vania's "Dagger idle" (Assassin), "idle 1 hand" (Warden) and "greatsword idle" (Cleric; vania has no hammer idle, and this one rests the hammer on the shoulder). They were uploaded through Open Cloud like the rest.

### VFX and sounds

`client/Effects.luau` plays them from the server's Fx events. The particle effects are generated into `src/shared/VfxLibrary.luau` by `tools/reupload/vfx.py`; textures keep the source's image IDs, which load in any game. Sounds are listed in `AssetIds.Sfx`. Short sound effects are public on Roblox, but any that a creator kept private will be silent; swap its ID if so.

| Event | VFX (source) | Sound (source) |
|---|---|---|
| Warden / Assassin / Cleric hit | slash / stab / blunt impact (vania) | sword hit (hxh), sword stab, blunt (vania) |
| Hit taken while blocking | block hit (hxh) | sword block (hxh) |
| Hit taken | blood hit (vania) | bloody hit (hxh) |
| Parry | parry burst (vania) | parry, sword clash (hxh) |
| Heal | small magic circle (vania) | heal, healing (Excry) |
| Boss Broken | block break (vania) | block break (vania) |
| Boss Ash Sweep | furious slam (vania) | blunt heavy (vania) |
| Attack starts, dodge, boss swing, boss cast | | swing, roll, great sword heavy, charge (vania) |

## Other places checked (2026-10-30)

| Place | Verdict |
|---|---|
| vania, hxh, CHAIN, jjk cool map | Cleared by Charles. vania (gothic fantasy) is the best match; CHAIN is horror; jjk is a map only |
| Quirkbound, Newest Ghoul RE, New moon | Not used. Their scripts carry "Saved by UniversalSynSaveInstance (Join to Copy Games)" and decompiler stamps, so they were copied from live games with an exploit |
| HAV DEV SERVER | Not used. Two small scripts (menu, quotes) are decompiled; the rest looks original |
| Excry Main Game, Cursed Reality, BATTLECOMBATR6, Anime Brigade, REFrameworkV2 | Cleared by Charles. Used: REFramework's Healing animation, Excry's heal, stab and boss sounds |

**Credit:** the Run System's licence asks for "Run and Walk System by @skaterstudios" in the game description. Add it before publishing.

Fixed copies of all four kits, with the new IDs already swapped in, are in the project files under `oathbound/fixed-kits/`. Insert a `.rbxm` with Explorer > right-click > Insert from File.

## Rig type

The run, wall run and bow animations are R6, the climb animations are R15. They cannot play on the other rig. The prototype forces R6 itself: `server/ForceR6.luau` puts an R6 StarterCharacter in StarterPlayer and dresses each character in the player's own avatar.

## Re-uploading

`tools/reupload/` holds the scripts that did this. They need Python 3 with `lz4` and `zstandard`, and an Open Cloud API key with `asset:write` in `ROBLOX_API_KEY`.

```sh
python3 tools/reupload/export.py out/ "Some Kit.rbxm"           # every KeyframeSequence -> out/*.rbxmx + manifest.json
# add a "display" name to each manifest entry, then:
python3 tools/reupload/upload.py out/manifest.json out/results.json   # resumable; asset IDs land in results.json
python3 tools/reupload/patch.py "Some Kit.rbxm" "Some Kit (fixed).rbxm" map.json   # map.json = {"oldId": "newId"}
```

Only re-upload animations from free kits or your own work.
