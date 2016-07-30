local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ARCANE = 62
local SPEC_FIRE = 63
local SPEC_FROST = 64

Cooldowns:RegisterSpells("MAGE", {
	[45438] = { -- Ice block
		cooldown = 300,
		duration = 10,
		charges = function(unit) return unit:HasTalent(16025) and 2 or 1 end
	},
	[2139] = { -- Counterspell
		cooldown = 24
	},

	-- Arcane
	[110959] = { -- Greater Invisibility
		cooldown = 120,
		duration = 4,
		spec = SPEC_ARCANE
	},

	-- Fire
	[31661] = { -- Dragon's Breath
		cooldown = 20,
		duration = 4,
		spec = SPEC_FIRE
	},

	-- Talents
	[113724] = { -- Ring of Frost
		cooldown = 45,
		duration = 10,
		talent = true
	},
})
