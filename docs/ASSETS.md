# Assets

An animation only plays in a game owned by the account (or group) that uploaded it. A foreign ID loads as an empty track that never ends, so animations from other people's places look broken or hang scripts. Every ID in `src/shared/AssetIds.luau` was uploaded to the Oathbound account (user 102707091) through Open Cloud on 2026-10-30.

## Where they came from

All four are free Creator Store kits. The animations were re-uploaded from the KeyframeSequences each kit ships in its `AnimSaves` folders. Nothing was taken from other people's games.

| Kit | Rig | Animations | Used in the prototype |
|---|---|---|---|
| Advanced R6 Run System (@skaterstudios) | R6 | Idle, walk and run in 4 directions | Yes, `client/Locomotion.luau` |
| R6 Wall Run (@skaterstudios) | R6 | Wall run and wall jump, left and right | Not yet |
| Advanced R15 Wall Climb System | R15 | Climb in 4 directions, climb idle, ledge hold/shimmy, vault | Not yet |
| Bow & Arrow System | R6 | Bow idle, run, aim, aim hold, aimed shot, shoot, plus 5 sounds | Not yet (for the Ranger) |

**Credit:** the Run System's licence asks for "Run and Walk System by @skaterstudios" in the game description. Add it before publishing.

Fixed copies of all four kits, with the new IDs already swapped in, are in the project files under `oathbound/fixed-kits/`. Insert a `.rbxm` with Explorer > right-click > Insert from File.

## Rig type

The run, wall run and bow animations are R6, the climb animations are R15. They cannot play on the other rig. The prototype's movement animations need **Game Settings > Avatar > Avatar Type: R6**; on R15 the default Roblox animations play and a warning is printed once.

## Re-uploading

`tools/reupload/` holds the scripts that did this. They need Python 3 with `lz4` and `zstandard`, and an Open Cloud API key with `asset:write` in `ROBLOX_API_KEY`.

```sh
python3 tools/reupload/export.py out/ "Some Kit.rbxm"           # every KeyframeSequence -> out/*.rbxmx + manifest.json
# add a "display" name to each manifest entry, then:
python3 tools/reupload/upload.py out/manifest.json out/results.json   # resumable; asset IDs land in results.json
python3 tools/reupload/patch.py "Some Kit.rbxm" "Some Kit (fixed).rbxm" map.json   # map.json = {"oldId": "newId"}
```

Only re-upload animations from free kits or your own work.
