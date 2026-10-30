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
| Cleric | Hammer 1 to 4 (Smite: hits the enemy in front and heals the most hurt ally) | Sanctuary: slam the ground. Mend: "Healing" from REFramework | Sword block |
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
| Heal, Mend cast, Sanctuary | magic circle on the floor (vania), scaled per spell; Sanctuary adds the furious slam | heal, healing (Excry) |
| Boss Broken | block break (vania) | block break (vania) |
| Boss Ash Sweep | furious slam (vania) | blunt heavy (vania) |
| Attack starts, dodge, boss swing, boss cast | | swing, roll, great sword heavy, charge (vania) |

## Other places checked (2026-10-30)

| Place | Verdict |
|---|---|
| vania, hxh, CHAIN, jjk cool map | Cleared by Charles. vania (gothic fantasy) is the best match; CHAIN is horror; jjk is a map only |
| Quirkbound, Newest Ghoul RE, New moon | Not used. Their scripts carry "Saved by UniversalSynSaveInstance (Join to Copy Games)" and decompiler stamps, so they were copied from live games with an exploit |
| HAV DEV SERVER | Not used. Two small scripts (menu, quotes) are decompiled; the rest looks original |
| Excry Main Game, Cursed Reality, BATTLECOMBATR6, Anime Brigade, REFrameworkV2 | Cleared by Charles. Used: REFramework's Healing animation, Excry's heal, stab and boss sounds, BATTLECOMBATR6's Hurt1 to Hurt3 |
| CHAIN, jjk cool map | Not used after all: a full scan found decompiler stamps (Synapse X in 34 CHAIN scripts, Potassium in two jjk settings modules) |
| Guns place, MW2019_VMs_1, Newest Ninja Main Menu, Project Mugetsu (all PM-* places) | Not used. Guns, MW2019 and Ninja Main Menu carry Synapse or UniversalSynSaveInstance stamps; Project Mugetsu is a live game's files |

### Animation survey (2026-10-30)

Every KeyframeSequence in the library (2,082) was scanned. All of them are R6; there are no R15 animations, so the game stays R6. Each candidate was previewed in Studio on a rig holding the class's weapon. The picks were uploaded to the Oathbound account from the PC with `tools/reupload/upload.luau` (a Lune port of `upload.py`) and are wired into `AssetIds.Combat`:

| Use | Animation | Source |
|---|---|---|
| Assassin Backstab | Gut Breaker: wind-up, overhead raise, downward plunge | vania |
| Assassin Finisher | Disarming Slash: low dip, rising slash, thrust | vania |
| Hit flinch (players and Duelists) | Hurt1, Hurt2, Hurt3 | BATTLECOMBATR6 |

### Ranger (Bow & Arrow System, BestRobloxLib)

The Ranger uses the Bow & Arrow System kit: its seven bow animations (`AssetIds.Bow`, uploaded earlier), its sounds (`AssetIds.BowSounds`) and its bow model, whose two meshes `server/Weapons.luau` loads by ID and hangs from a "RootPart" joined to the Left Arm, the part the bow animations move. Arrows are drawn by `client/Effects.luau` from parts, after the kit's arrow (a union that scripts cannot create). Quick Shot and Volley play "Shoot"; Aimed Shot and Piercing Arrow draw with "Aim" and release with "Aimed Shot"; "Bow Idle" is the hold. The kit's scripts were not used.

BestRobloxLib, checked for dump stamps: Advanced Mining System and FREE R6 Fishing System each carry a decompiler stamp and were not used. The rest (Bow & Arrow System, Run System, Wall Run, Wall Climb, Lantern, Ragdoll, Sprint) are clean.

Looked at and rejected: Excry "manaimbue" (a crouched punch charge, not a heal), REFramework "Healing" and vania "NPCPoint" (no Hilt pose, so the hammer sticks out), vania "Waterfall dance" (a 3.3 s acrobatic leap), vania "greataxe skill 1" (a 2.6 s spin). Excry's "Jump Smash", "Death" and "Stun 1" are on a different, non-Roblox rig and do not move an R6 character. None of the cleared files has a hammer heal or cast, so Mend and Sanctuary keep their current animations until a fitting one is found or made.

**Credit:** the Run System's licence asks for "Run and Walk System by @skaterstudios" in the game description. Add it before publishing.

Fixed copies of all four kits, with the new IDs already swapped in, are in the project files under `oathbound/fixed-kits/`. Insert a `.rbxm` with Explorer > right-click > Insert from File.

### Gear looks (2026-10-30)

Rule for picks: Western medieval fantasy (knight, ranger, priest, rogue, noble); no modern wear, no East Asian garments, no named-character costumes, nothing oversized. Every pick was previewed on an R6 rig.

**Body Armor is one worn outfit** (Shirt and Pants templates, applied together by `server/Gear.luau`; the avatar's own clothing returns when the slot is empty). Chest and legs used to be separate slots, but outfits from different games mix art styles and clashed when combined, so each outfit is now one item with the stat budget of both (rolls x1.6). A light tint [Proto] grades every outfit into one muted palette.

| Outfit | Source |
|---|---|
| Wayfarer's Garb (starter) | vania NPC Brown Trenchcoat |
| Vigil Captain's Uniform | vania Imperial Captain |
| Nobleman's Frock, Navy Nobleman's Frock | vania Black / Navy Nobleman |
| Nightwatch Coat, Gravecloth, Duskwalker Coat, Tattered Wanderer's Rags, Templar Vestments | Excry NonDialogue clothing |
| Sapphire Plate | vania Workspace.Map.blackstar52905 |
| Frostfur Hunter's Garb | Excry Klaus |
| Beastfur Harness | hxh Uvogin |
| Shadowleather Garb | Excry Qix |
| Wrapped Leathers | Excry TheStranger |
| Bandaged Leathers | Excry NpcTemplate |
| Priest's Cassock | hxh Priest |

**Small 3D pieces** are models in the place under `ServerStorage.OathGear` (save the place to keep them). Every armour slot shows something; head and ring slots are hidden until they have real models.

| Slot | Items | Source |
|---|---|---|
| Hands | Leather Gauntlets, Linen Wraps | vania Arms |
| Feet | Leather, Iron, Blackened, Bone Shin Guards | vania Warrior Greaves leg plates, re-finished |
| Neck | Wool Scarf, Crimson Cowl, Holy Chain, Fur Mantle, Snow Fur Mantle (vania); Gold and Silver Necklace, Ragged Scarf (Excry); Checked Scarf (hxh) | as listed |
| Belt | Leather Strap, Traveller's Harness, Crossed Bandolier, Satchel (vania Chest); Wool Sash (hxh Waistband) | as listed |
| Cleric off-hand | Lantern of Vigil | vania |

Bright white pieces are retinted to linen and wool. Weapons: 7 Warden swords, 6 Assassin daggers, 6 Cleric hammers, 6 Ranger bows; new models Camilla Sabre and Vamp Dagger 1 and 2 (vania), plus blackened and gilded finishes and two bow tints. Shields, tomes and quivers have no model in the cleared files, so those off-hands still show nothing.

Rejected: vania Buckled Cloak (a skinned mesh that renders broken on R6), hxh Bandages and Excry Bronze Necklace (not visible on R6), vania Scarf 3 (a thin band), Gear Hammer (steampunk); the vania Boss Cloak (white veil), Warrior Chausses (oversized); haori, gi and hakama sets, bead necklaces (East Asian); Kurapika, Chrollo, Netero, Feitan outfits (named characters); farmer, bandit, waistcoat, suits, hoodies, jeans, graphic tees, kimono and tactical gear from the remaining Excry, hxh, REFramework and Anime Brigade clothing (modern, sci-fi or East Asian).

No shields, tomes, quivers, boots or rings exist in the cleared files: head, ring and most off-hands are stats only.

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
