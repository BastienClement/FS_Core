local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BEASTMASTERY = 253
local SPEC_MARKSMANSHIP = 254
local SPEC_SURVIVAL = 255

local SPEC_RANGED = { SPEC_BEASTMASTERY, SPEC_MARKSMANSHIP }

Cooldowns:RegisterSpells("HUNTER", {
	[186265] = { -- Aspect of the Turtle
		cooldown = 180,
		duration = 8
	},

	-- Survival
	[187707] = { -- Muzzle
		cooldown = 15,
		duration = 3,
		spec = SPEC_SURVIVAL
	},

	-- Shared
	[147362] = { -- Counter Shot
		cooldown = 24,
		duration = 3,
		spec = SPEC_RANGED
	},

	-- Talents
	[109248] = { -- Binding Shot
		cooldown = 45,
		duration = 10,
		talent = true
	},
})
