-- Effect = Ceiling * R / (R + 300F), GDD v2 section 5.
return function(t)
	local StatCurve = t.shared("StatCurve")

	t.test("K is 1,182 at level 50", function()
		t.near(StatCurve.k(50), 1182)
	end)

	t.test("rating equal to K gives half the ceiling", function()
		t.near(StatCurve.effect(1182, 0.30, 50), 0.15)
		t.near(StatCurve.effect(1182, 100, 50), 50)
	end)

	t.test("no stat reaches its ceiling", function()
		local e = StatCurve.effect(1e6, 0.30, 50)
		assert(e < 0.30, "effect reached the ceiling")
	end)

	t.test("zero or negative rating gives nothing", function()
		t.near(StatCurve.effect(0, 0.30, 50), 0)
		t.near(StatCurve.effect(-50, 0.30, 50), 0)
	end)

	t.test("derived stats start at the base values", function()
		local d = StatCurve.derive(nil, 50)
		t.near(d.critChance, 0.05)
		t.near(d.critMult, 1.5)
		t.near(d.actionSpeed, 0)
		t.near(d.vitality, 0)
	end)

	t.test("crit chance tops out below 50% total", function()
		local d = StatCurve.derive({ critChance = 1e6 }, 50)
		assert(d.critChance < 0.50 and d.critChance > 0.49, "crit chance " .. d.critChance)
	end)
end
