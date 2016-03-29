local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_PROT = 0
local SPEC_ARMS = 71 -- Maybe swapped
local SPEC_FURY = 72 -- Maybe swapped

Cooldowns:RegisterSpells("WARRIOR", {
	[97462] = { -- Rallying Cry
		cooldown = 180,
		duration = 10,
		spec = { SPEC_ARMS, SPEC_FURY }
	},
	[114030] = { -- Vigilance
		cooldown = 120,
		duration = 12,
		talent = 19676
	},
	[3411] = { -- Intervene
		cooldown = 30,
		duration = 10
	},
})
