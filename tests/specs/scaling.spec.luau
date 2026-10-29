-- Checks against the tables in GDD v2, section 5 ("Scaling").
return function(t)
	local Scaling = t.shared("Scaling")

	t.test("level factor F", function()
		t.near(Scaling.levelFactor(1), 1.00)
		t.near(Scaling.levelFactor(20), 2.14)
		t.near(Scaling.levelFactor(50), 3.94)
	end)

	t.test("gear factor G", function()
		t.near(Scaling.gearFactor(50, 50), 1.00)
		t.near(Scaling.gearFactor(65, 50), 1.30)
	end)

	t.test("weapon damage matches the GDD table", function()
		t.near(Scaling.weaponDamage(1, 1), 100)
		t.near(Scaling.weaponDamage(20, 20), 214)
		t.near(Scaling.weaponDamage(50, 50), 394)
		t.near(Scaling.weaponDamage(50, 65), 512.2)
	end)

	t.test("health matches the GDD table", function()
		t.near(Scaling.maxHealth("light", 50, 65), 8195.2, 0.01)
		t.near(Scaling.maxHealth("medium", 50, 65), 10244, 0.01)
		t.near(Scaling.maxHealth("heavy", 50, 65), 12805, 0.01)
		-- Tank evolutions get +25%: the Warden at tier 1 top
		t.near(Scaling.maxHealth("heavy", 50, 65, Scaling.TANK_HP_BONUS), 16006.25, 0.01)
	end)

	t.test("armor DR is fixed per type at every level", function()
		for _, level in { 1, 20, 50 } do
			t.near(Scaling.armorDR(Scaling.armorRating("light", level), level), 0.15, 0.001)
			t.near(Scaling.armorDR(Scaling.armorRating("medium", level), level), 0.25, 0.001)
			t.near(Scaling.armorDR(Scaling.armorRating("heavy", level), level), 0.35, 0.001)
		end
	end)
end
