-- Combat-wide constants from Oathbound GDD v2, sections 4 and 5.
-- Tags: [A] = placeholder value to be tuned in playtests, [Proto] = chosen for this prototype only,
-- not in the design doc. See docs/PLACEHOLDERS.md for the full list.

local Constants = {}

-- Timeline
Constants.TICK = 0.05 -- seconds per server tick [A]
Constants.ACTION_SPEED_CAP = 0.30 -- hard total, buffs included
Constants.ACTION_SPEED_STEP = 0.05 -- quantized for server validation (GDD section 13)

-- Arrows (server/Projectiles simulates them; client/Effects draws them on the same arc)
Constants.ARROW_GRAVITY = 30 -- studs per second squared: a slight drop that only matters at long range [Proto]
Constants.ARROW_MUZZLE = CFrame.new(-0.5, 1, -2) -- from the root: the bow, held in the left hand [Proto]

-- Defense
Constants.PARRY_WINDOW = 0.20 -- seconds after block starts; never changed by stats
Constants.DODGE_INVULN = 0.25 -- seconds; never changed by stats
Constants.DODGE_COOLDOWN = 0.8 -- [Proto] stops dodge spam; not in the GDD
Constants.BLOCK_DR = 0.70 -- on white frontal hits
Constants.STAMINA_POOL = 100
Constants.STAMINA_REGEN = 20 -- per second while not blocking
Constants.STAMINA_PER_BLOCK = 15

-- Movement [Proto]: sprint, climb and glide share the stamina pool with blocking.
Constants.ANIM_FADE = 0.2 -- seconds; one crossfade for walk, run, climb, glide and tool holds so they blend alike
Constants.WALK_SPEED = 16 -- studs per second (Roblox default)
Constants.SPRINT_SPEED = 24
Constants.CLIMB_SPEED = 8
Constants.GLIDE_SPEED = 30 -- forward, while sinking at GLIDE_SINK
Constants.GLIDE_SINK = 7
-- Stamina per second each one costs, and what is needed to start one.
Constants.EXERTION_DRAIN = { sprint = 12, climb = 15, glide = 7 }
Constants.EXERTION_MIN = 15
Constants.JUMP_COST = 8 -- stamina per jump; below it you cannot jump
Constants.STAMINA_REGEN_DELAY = 1 -- seconds after sprinting, climbing or gliding before stamina comes back

-- Damage categories and caps
Constants.CAP_O_SELF = 0.25 -- [A]
Constants.CAP_O_EXT = 0.15 -- [A]
Constants.CAP_VULN = 0.15 -- [A]
Constants.CAP_PASSIVE_DR = 0.40
Constants.CAP_EXTERNAL_DR = 0.20
Constants.CAP_TOTAL_DR = 0.80
Constants.CAP_SHIELD_FRACTION = 0.30 -- of max HP per target

-- Crits
Constants.BASE_CRIT_CHANCE = 0.05
Constants.BASE_CRIT_MULT = 1.5
Constants.HEAL_CRIT_MULT = 1.5 -- heals crit at a fixed 1.5x

-- Boss rules
Constants.BREAK_STUN = 3.0 -- seconds Broken
Constants.BREAK_LOCK = 25.0 -- seconds the meter stays locked after a Break
Constants.INTERRUPT_LOCK = 15.0 -- an interrupted cast cannot be interrupted again for this long
Constants.TANK_THREAT_MULT = 3.0
Constants.HEAL_THREAT_MULT = 0.5 -- [Proto]

-- Boss hit sizes are written as raw damage against light armor at the tier's item level.
Constants.REFERENCE_ARMOR = "light"

return Constants
