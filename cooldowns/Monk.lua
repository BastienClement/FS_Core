local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_MIST = 270
local SPEC_BREW = 0
local SPEC_WIND = 0

Cooldowns:RegisterSpells("MONK", {
	[115310] = { -- Revival
		cooldown = 180,
		spec = SPEC_MIST
	},
	[116849] = { -- Life Cocoon
		cooldown = 100,
		duration = 12,
		spec = SPEC_MIST
	},
})
