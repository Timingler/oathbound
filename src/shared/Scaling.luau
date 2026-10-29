-- Level and gear scaling from Oathbound GDD v2, section 5. Every value is a prototype placeholder [A].

local Scaling = {}

-- HP_class by armor type, before the level and gear factors.
Scaling.HP_CLASS = {
	light = 1600,
	medium = 2000,
	heavy = 2500,
}

-- Armor coefficient a per armor type. With A = a * F, DR = a / (a + 500) is fixed per type:
-- 15% light, 25% medium, 35% heavy.
Scaling.ARMOR_COEFF = {
	light = 88.2,
	medium = 166.7,
	heavy = 269.2,
}

Scaling.TANK_HP_BONUS = 0.25
Scaling.DUELIST_HP_BONUS = 0.10

-- Level factor F = 1 + 0.06(L - 1)
function Scaling.levelFactor(level: number): number
	return 1 + 0.06 * (level - 1)
end

-- Gear factor G = 1 + 0.02(iL - L)
function Scaling.gearFactor(itemLevel: number, level: number): number
	return 1 + 0.02 * (itemLevel - level)
end

-- Weapon Damage WD = 100 * F * G. Every damage, heal and shield is a coefficient times WD.
function Scaling.weaponDamage(level: number, itemLevel: number): number
	return 100 * Scaling.levelFactor(level) * Scaling.gearFactor(itemLevel, level)
end

-- HP = HP_class * F * G * (1 + role bonus)
function Scaling.maxHealth(armorType: string, level: number, itemLevel: number, roleBonus: number?): number
	local base = Scaling.HP_CLASS[armorType]
	assert(base, "unknown armor type " .. tostring(armorType))
	return base * Scaling.levelFactor(level) * Scaling.gearFactor(itemLevel, level) * (1 + (roleBonus or 0))
end

-- Armor rating A = a * F (the recommended rule: item level adds HP, not DR).
function Scaling.armorRating(armorType: string, level: number): number
	local a = Scaling.ARMOR_COEFF[armorType]
	assert(a, "unknown armor type " .. tostring(armorType))
	return a * Scaling.levelFactor(level)
end

-- DR = A / (A + 500F)
function Scaling.armorDR(armorRating: number, level: number): number
	return armorRating / (armorRating + 500 * Scaling.levelFactor(level))
end

return Scaling
