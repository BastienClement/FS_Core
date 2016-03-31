local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ARMS = 71
local SPEC_FURY = 72
local SPEC_PROT = 0

Cooldowns:RegisterSpells("WARRIOR", {
	[6552] = { -- Pummel
		cooldown = 15,
		duration = 4
	},
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
