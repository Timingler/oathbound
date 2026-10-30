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

-- Bow & Arrow System. R6 only. The Ranger's bow animations (AssetIds.Combat.Ranger and Hold.Ranger).
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

-- Combat animations from the vania place (Cleric Mend from REFramework), keyed by kit and ability id. R6 only.
-- basic = the 4-hit combo, played in turn. `length` and `hit` are in seconds: `hit` is the strike, when the weapon
-- moves fastest, measured by stepping each animation on a rig holding the class's weapon. server/Animations
-- times the strike to land as the wind-up ends.
AssetIds.Combat = {
	Warden = {
		basic = {
			{ id = 103295286556261, length = 0.7, hit = 0.33 },
			{ id = 136079389253694, length = 0.7, hit = 0.3 },
			{ id = 119147741433206, length = 0.7, hit = 0.3 },
			{ id = 81744799754944, length = 0.7, hit = 0.27 },
		},
		bash = { id = 81443323768646, length = 0.983, hit = 0.33 },
		block = { id = 124711076243259, length = 0.3 },
		cleave = { id = 132114753474752, length = 1.383, hit = 1.27 },
		intercept = { id = 78513902446355, length = 0.95, hit = 0.7 },
	},
	Assassin = {
		basic = {
			{ id = 106658428162028, length = 0.7, hit = 0.27 },
			{ id = 133080188391913, length = 0.7, hit = 0.33 },
			{ id = 139000887992280, length = 0.7, hit = 0.27 },
			{ id = 98167371563431, length = 0.7, hit = 0.33 },
		},
		backstab = { id = 139960105120020, length = 0.967, hit = 0.67 }, -- vania "Gut Breaker": raise and plunge
		block = { id = 89797086934236, length = 0.3 },
		finisher = { id = 91687057719601, length = 1.183, hit = 1.07 }, -- vania "Disarming Slash": dip, rising slash, thrust
		poison = { id = 125562417023753, length = 1.5, hit = 1.2 },
	},
	Cleric = {
		basic = {
			{ id = 137789199869379, length = 0.75, hit = 0.4 },
			{ id = 122735676513005, length = 0.767, hit = 0.4 },
			{ id = 129012896652443, length = 0.75, hit = 0.4 },
			{ id = 122695545333172, length = 0.75, hit = 0.4 },
		},
		mend = { id = 79522147824602, length = 1.65, hit = 0.4 }, -- "Healing", from the REFramework place
		sanctuary = { id = 72265550049226, length = 1.283, hit = 0.37 },
	},
	-- Bow & Arrow System (AssetIds.Bow). For a shot, `hit` is the release. Long draws play "Aim" (draw and hold),
	-- then `release` ("Aimed Shot") starts `release.hit` seconds before the wind-up ends so the string lets go on
	-- the fire tick.
	Ranger = {
		basic = {
			{ id = 107887253067644, length = 0.75, hit = 0.5 }, -- Shoot
		},
		aimed = { id = 134782919099562, length = 0.67, hit = 0.67, release = { id = 71054802195595, length = 0.47, hit = 0.3 } },
		pierce = { id = 134782919099562, length = 0.67, hit = 0.67, release = { id = 71054802195595, length = 0.47, hit = 0.3 } },
		volley = { id = 107887253067644, length = 0.75, hit = 0.5 },
	},
	Common = {
		parry1 = { id = 92880082908381, length = 0.5 },
		parry2 = { id = 81125391426221, length = 0.4 },
		roll = { id = 123385016461782, length = 1.167, hit = 0.73 },
		-- Hit flinches from BATTLECOMBATR6 ("Hurt1" to "Hurt3"), one picked at random when a hit lands.
		hurt = {
			{ id = 102814487565218, length = 0.45 },
			{ id = 119621642557759, length = 0.45 },
			{ id = 101378513702948, length = 0.45 },
		},
	},
}

-- Weapon hold poses from the vania place (its WeaponHandler loops one per weapon type), keyed by kit. R6 only.
-- They raise the arm so the weapon sits in the hand; without one the arm hangs and the weapon sticks out of the hip.
AssetIds.Hold = {
	Warden = 77132799404420, -- "idle 1 hand"
	Assassin = 134201934974804, -- "Dagger idle"
	Cleric = 92760080918876, -- "greatsword idle": vania has no hammer idle; this one rests the hammer on the shoulder
	Ranger = 121372386174806, -- Bow & Arrow System "Bow Idle"
}

-- Combat sounds from the vania, hxh and Excry places, played by client/Effects.luau. Short sound effects are public
-- on Roblox, so these IDs play in any game; one that does not will just stay silent. Lists pick one at random.
AssetIds.Sfx = {
	swing = { 4898257652, 4898262512 },
	slash = { 3932145654, 3932145123, 3932142219, 3932141920 },
	stab = { 4471648128, 2017482557 },
	blunt = { 12327206250, 12327206688, 12327207277 },
	blockHit = { 604798957, 604238471, 604800072 },
	parry = { 4516507682, 4953118406, 4953118940 },
	guardBreak = { 4898185564 },
	hurt = { 3739363791, 4086189694, 4086190131 },
	heal = { 2017454590, 9038523649 },
	dodge = { 12076648787 },
	bossSwing = { 6589514393 },
	bossSlam = { 5540424854, 12826036518 },
	bossCast = { 6856435312 },
	-- Bow & Arrow System sounds (AssetIds.BowSounds), uploaded to the Oathbound account.
	bowDraw = { 81940370131397 },
	bowRelease = { 117085747216533 },
	arrowHit = { 92587572434465 },
}

function AssetIds.uri(id: number): string
	return "rbxassetid://" .. tostring(id)
end

return AssetIds
