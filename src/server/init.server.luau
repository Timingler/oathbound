-- Oathbound prototype, Phase 1: the combat arena.

local CombatService = require(script.CombatService)
local Actor = require(script.Actor)
local Boss = require(script.Boss)
local Arena = require(script.Arena)

local arena = Arena.build()

local bossActor = Actor.new({
	kind = "boss",
	name = "Ashen Sentinel",
	team = "enemies",
	model = arena.boss,
	level = 50,
	itemLevel = 65,
	maxHealth = Boss.MAX_HEALTH,
})
CombatService.addEnemy(bossActor)
CombatService.boss = Boss.new(CombatService, bossActor, arena.bossHome)

local dummyActor = Actor.new({
	kind = "dummy",
	name = "Training Dummy",
	team = "enemies",
	model = arena.dummy,
	level = 50,
	itemLevel = 65,
	maxHealth = 1e9,
})
dummyActor.radius = 2
dummyActor.enemyDR = 0
CombatService.addEnemy(dummyActor)
CombatService.dummy = dummyActor

CombatService.start()
