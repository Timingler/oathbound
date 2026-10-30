-- Animation and sound asset IDs owned by the Oathbound account. Animations only play in games owned by their
-- uploader, so these are re-uploads of the KeyframeSequences shipped in free Creator Store kits.
-- See docs/ASSETS.md for where each one came from and how to re-upload.

local AssetIds = {}

-- Advanced R6 Run System by @skaterstudios (credit required in the game description). R6 only.
-- W/A/S/D = forward, left, back, right relative to where the character faces.
AssetIds.Move = {
	Idle = 89839883053889,
	["Walk W"] = 106970633464919,
	["Walk A"] = 140016582465266,
	["Walk S"] = 70665089059549,
	["Walk D"] = 72544306561368,
	["Run W"] = 125413751421050,
	["Run A"] = 93356765468766,
	["Run S"] = 117391570987027,
	["Run D"] = 110563591852153,
}

-- R6 Wall Run by @skaterstudios. R6 only. Not used yet.
AssetIds.WallRun = {
	["Run Left"] = 133083618366257,
	["Run Right"] = 100348661529441,
	["Jump Left"] = 137843580257876,
	["Jump Right"] = 127743768354579,
}

-- Advanced R15 Wall Climb System. R15 only. Not used yet.
AssetIds.Climb = {
	Idle = 70583893998184,
	Up = 96393512824760,
	Down = 91296530240745,
	Left = 118316720143290,
	Right = 118936463519043,
	["Ledge Hold"] = 139105379459235,
	["Ledge Left"] = 114380899027471,
	["Ledge Right"] = 92294276485636,
	["Vault Left"] = 80723442441009,
	["Vault Right"] = 128307554666894,
}

-- Bow & Arrow System. R6 only. For the Ranger (Marksman) when it is added.
AssetIds.Bow = {
	Idle = 121372386174806,
	Run = 96497238936992,
	Aim = 134782919099562,
	["Aim Hold"] = 122431602370904,
	["Aimed Shot"] = 71054802195595,
	["Aimed Shot Looped"] = 116560834685236,
	Shoot = 107887253067644,
}

AssetIds.BowSounds = {
	["Arrow Hit"] = 92587572434465,
	["Bow Hold"] = 86422855479362,
	["Bow Ready"] = 81940370131397,
	["Bow Release"] = 117085747216533,
	Cancel = 111342790429258,
}

-- Combat animations from the vania place, keyed by kit and ability id. R6 only. `length` is in seconds, so the
-- server can stretch each one over the action's wind-up and recovery. basic = the 4-hit combo, played in turn.
AssetIds.Combat = {
	Warden = {
		basic = {
			{ id = 103295286556261, length = 0.7 },
			{ id = 136079389253694, length = 0.7 },
			{ id = 119147741433206, length = 0.7 },
			{ id = 81744799754944, length = 0.7 },
		},
		bash = { id = 81443323768646, length = 0.983 },
		block = { id = 124711076243259, length = 0.3 },
		cleave = { id = 132114753474752, length = 1.383 },
		intercept = { id = 78513902446355, length = 0.95 },
	},
	Assassin = {
		basic = {
			{ id = 106658428162028, length = 0.7 },
			{ id = 133080188391913, length = 0.7 },
			{ id = 139000887992280, length = 0.7 },
			{ id = 98167371563431, length = 0.7 },
		},
		backstab = { id = 124203937681949, length = 0.483 },
		block = { id = 89797086934236, length = 0.3 },
		finisher = { id = 108220663192078, length = 1.083 },
		poison = { id = 125562417023753, length = 1.5 },
	},
	Cleric = {
		basic = {
			{ id = 137789199869379, length = 0.75 },
			{ id = 122735676513005, length = 0.767 },
			{ id = 129012896652443, length = 0.75 },
			{ id = 122695545333172, length = 0.75 },
		},
		mend = { id = 79522147824602, length = 1.65 }, -- "Healing", from the REFramework place
		sanctuary = { id = 72265550049226, length = 1.283 },
	},
	Common = {
		parry1 = { id = 92880082908381, length = 0.5 },
		parry2 = { id = 81125391426221, length = 0.4 },
		roll = { id = 123385016461782, length = 1.167 },
	},
}

-- Combat sounds from the vania, hxh and Excry places, played by client/Effects.luau. Short sound effects are public
-- on Roblox, so these IDs play in any game; one that does not will just stay silent. Lists pick one at random.
AssetIds.Sfx = {
	swing = { 4898257652, 4898262512 },
	slash = { 3932145654, 3932145123, 3932142219, 3932141920 },
	stab = { 4471648128 },
	blunt = { 12327206250, 12327206688, 12327207277 },
	blockHit = { 604798957, 604238471, 604800072 },
	parry = { 4516507682, 4953118406, 4953118940 },
	guardBreak = { 4898185564 },
	hurt = { 3739363791, 4086189694, 4086190131 },
	heal = { 12350726490 },
	dodge = { 12076648787 },
	bossSwing = { 12548800970 },
	bossSlam = { 12826036518 },
	bossCast = { 6856435312 },
}

function AssetIds.uri(id: number): string
	return "rbxassetid://" .. tostring(id)
end

return AssetIds
