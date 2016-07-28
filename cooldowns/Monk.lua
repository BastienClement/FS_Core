local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BREWMASTER = 268
local SPEC_WINDWALKER = 269
local SPEC_MISTWEAVER = 270

Cooldowns:RegisterSpells("MONK", {
	[119996] = { -- Transcendence: Transert
		cooldown = 25
	},

	-- Brewmaster
	[115176] = { -- Zen Meditation
		cooldown = 300,
		duration = 8,
		spec = SPEC_BREWMASTER
	},

	-- Windwalker
	[122470] = { -- Touch of Karma
		cooldown = 90,
		duration = 6,
		spec = SPEC_WINDWALKER
	},

	-- Mistsweaver
	[115310] = { -- Revival
		cooldown = 180,
		spec = SPEC_MISTWEAVER
	},
	[116849] = { -- Life Cocoon
		cooldown = 180,
		duration = 12,
		spec = SPEC_MISTWEAVER
	},

	-- Shared
	[116705] = { -- Spear Hand Strike
		cooldown = 15,
		duration = 4,
		spec = { SPEC_BREWMASTER, SPEC_WINDWALKER }
	},

	-- Talents
	[122783] = { -- Diffuse Magic
		cooldown = 120,
		duration = 6,
		talent = true
	},
	[119381] = { -- Leg Sweep
		cooldown = 45,
		duration = 5,
		talent = true
	},
	[116844] = { -- Ring of Peace
		cooldown = 45,
		duration = 8,
		talent = true
	},
})
