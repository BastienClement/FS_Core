local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

Cooldowns:RegisterSpells({
	--
	-- Gul'dan
	--
	[217830] = { -- Scattering Field (Heal)
		cooldown = 30,
		duration = 6,
		encounter = 1866,
		available = function(unit) return unit.info.spec_role == "HEALER" end
	},
	[210296] = { -- Resonant Barrier (Tank)
		cooldown = 180,
		duration = 6,
		encounter = 1866,
		available = function(unit) return unit.info.spec_role == "TANK" end
	},
	[210339] = { -- Time Dilation (DPS)
		cooldown = 45,
		duration = 10,
		encounter = 1866,
		available = function(unit) return unit.info.spec_role == "DAMAGER" end
	},
})
