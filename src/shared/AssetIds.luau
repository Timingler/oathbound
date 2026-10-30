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

function AssetIds.uri(id: number): string
	return "rbxassetid://" .. tostring(id)
end

return AssetIds
