local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BREWMASTER = 268
local SPEC_WINDWALKER = 269
local SPEC_MISTWEAVER = 270

Cooldowns:RegisterSpells("MONK", {
	[119996] = { -- Transcendence: Transert
		cooldown = 25
	},

	--
	-- Mistsweaver
	--
	[115310] = { -- Revival
		cooldown = 180,
		spec = SPEC_MISTWEAVER
	},
	[116849] = { -- Life Cocoon
		cooldown = 100,
		duration = 12,
		spec = SPEC_MISTWEAVER
	},
})
