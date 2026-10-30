-- Oathbound prototype, Phase 1: the combat arena.

local CombatService = require(script.CombatService)
local Actor = require(script.Actor)
local Boss = require(script.Boss)
local Arena = require(script.Arena)
local ForceR6 = require(script.ForceR6)
local Duelist = require(script.Duelist)

-- Before anyone spawns: every character is R6, which all the animations need.
ForceR6.start()

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

local dummy = Duelist.new(CombatService, { name = "Training Dummy", home = arena.dummyHome, passive = true })
CombatService.dummy = dummy.actor

Duelist.new(CombatService, { name = "Hollow Duelist", home = arena.duelistHome })

CombatService.start()
