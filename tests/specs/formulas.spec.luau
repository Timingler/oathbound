-- Combat formulas and caps, GDD v2 section 4.
return function(t)
	local Formulas = t.shared("Formulas")

	t.test("Action Speed is capped at 30% and quantized to 5% steps", function()
		t.near(Formulas.quantizeActionSpeed(0.12), 0.10)
		t.near(Formulas.quantizeActionSpeed(0.15), 0.15)
		t.near(Formulas.quantizeActionSpeed(0.29), 0.25)
		t.near(Formulas.quantizeActionSpeed(0.80), 0.30)
		t.near(Formulas.quantizeActionSpeed(-1), 0)
	end)

	t.test("action time divides by 1 + Action Speed", function()
		t.near(Formulas.actionTime(0.30, 0.15), 0.30 / 1.15)
		t.near(Formulas.actionTime(0.25, 0.25), 0.20)
	end)

	t.test("Ability Haste cooldown with tags", function()
		t.near(Formulas.cooldown(6, 100, 1.0), 3.0)
		t.near(Formulas.cooldown(12, 100, 0.5), 8.0)
		t.near(Formulas.cooldown(20, 100, 0), 20)
	end)

	t.test("Efficiency cost", function()
		t.near(Formulas.cost(45, 60), 28.125)
		t.near(Formulas.cost(45, 0), 45)
	end)

	t.test("expected crit multiplier", function()
		t.near(Formulas.expectedCrit(0.05, 1.5), 1.025)
		t.near(Formulas.expectedCrit(0.5, 2.0), 1.5)
	end)

	t.test("crit roll uses the caller's random number", function()
		local m, crit = Formulas.rollCrit(0.25, 1.8, 0.10)
		t.near(m, 1.8)
		t.equal(crit, true)
		m, crit = Formulas.rollCrit(0.25, 1.8, 0.90)
		t.near(m, 1)
		t.equal(crit, false)
	end)

	t.test("outgoing categories are capped separately, then multiply", function()
		t.near(Formulas.outgoingMultiplier(nil), 1)
		t.near(Formulas.outgoingMultiplier({ ownBonus = 0.5, externalBonus = 0.5, vulnerability = 0.5 }), 1.25 * 1.15 * 1.15)
	end)

	t.test("damage reduction caps", function()
		-- passive is capped at 40%
		t.near(Formulas.totalDR({ passive = 0.6 }), 0.40)
		-- external is capped at 20%
		t.near(Formulas.totalDR({ external = 0.5 }), 0.20)
		-- heavy armor blocking: 1 - 0.65 * 0.3 = 0.805, capped at 80%
		t.near(Formulas.totalDR({ passive = 0.35, block = 0.7 }), 0.80)
		-- light armor blocking: 1 - 0.85 * 0.3 = 0.745
		t.near(Formulas.totalDR({ passive = 0.15, block = 0.7 }), 0.745)
	end)

	t.test("hits written against light armor convert to other armor", function()
		local raw = Formulas.rawFromWritten(8000, 0.15)
		t.near(raw * (1 - 0.15), 8000)
		t.near(raw * (1 - 0.35), 8000 * 0.65 / 0.85, 1e-6)
	end)

	t.test("shields absorb after DR and cap at 30% of max HP", function()
		local through, left = Formulas.absorb(1000, 300)
		t.near(through, 700)
		t.near(left, 0)
		through, left = Formulas.absorb(200, 300)
		t.near(through, 0)
		t.near(left, 100)
		t.near(Formulas.capShield(5000, 10000), 3000)
	end)

	t.test("heals clamp to missing HP", function()
		local eff, over = Formulas.clampHeal(1500, 9000, 10000)
		t.near(eff, 1000)
		t.near(over, 500)
	end)

	t.test("revive charges are ceil(players / 5)", function()
		t.equal(Formulas.reviveCharges(5), 1)
		t.equal(Formulas.reviveCharges(6), 2)
		t.equal(Formulas.reviveCharges(10), 2)
	end)
end
