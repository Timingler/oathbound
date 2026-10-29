-- Kit data sanity: every value the server reads is present.
return function(t)
	local Kits = t.shared("Kits")

	t.test("three prototype classes, one per role", function()
		t.equal(#Kits.ORDER, 3)
		t.equal(Kits.Assassin.role, "damage")
		t.equal(Kits.Cleric.role, "healer")
		t.equal(Kits.Warden.role, "tank")
		t.equal(Kits.Warden.isTank, true)
	end)

	t.test("every timed ability has wind-up, recovery and a known effect", function()
		local effects = { strike = true, finisher = true, dot = true, heal = true, areaHeal = true, cleave = true, smokeStep = true, intercept = true }
		for _, name in Kits.ORDER do
			local kit = Kits[name]
			local list = {}
			for _, def in { kit.basic, kit.heavy or false, kit.signatureAction or false } do
				if def then
					table.insert(list, def)
				end
			end
			for _, s in kit.skills do
				table.insert(list, s)
			end
			for _, def in list do
				assert(effects[def.effect], name .. "." .. def.id .. " has unknown effect " .. tostring(def.effect))
				assert(type(def.windup) == "number" and type(def.recovery) == "number", name .. "." .. def.id .. " timing")
				if def.cooldown then
					assert(def.hasteTag ~= nil, name .. "." .. def.id .. " needs a haste tag")
				end
			end
			assert(#kit.skills <= 3, name .. " has more than 3 skills")
		end
	end)

	t.test("interrupts and mobility use the 0.5 haste tag", function()
		t.equal(Kits.Warden.skills[1].hasteTag, 0.5) -- Shield Bash
		t.equal(Kits.Assassin.skills[3].hasteTag, 0.5) -- Smoke Step
	end)
end
