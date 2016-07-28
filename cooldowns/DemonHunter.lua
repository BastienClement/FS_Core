local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HAVOC = 577
local SPEC_VENGEANCE = 581

Cooldowns:RegisterSpells("DEMONHUNTER", {
	[196718] = { -- Darkness
		cooldown = 180,
		duration = 8,
	},
	[179057] = { -- Chaos Nova
		cooldown = 60,
		duration = 5,
		-- TODO: Consuming orbs reduces CD
	},
	[183752] = { -- Consume Magic
		cooldown = 15,
		duration = 3,
	},

	-- Vengeance
	[202138] = { -- Sigil of Chains
		cooldown = 120,
		duration = 2,
		spec = SPEC_VENGEANCE
		-- TODO: Duration & cooldown affected by talent (time to activate)
	},
	[202137] = { -- Sigil of Silence
		cooldown = 60,
		duration = 2,
		spec = SPEC_VENGEANCE
		-- TODO: Duration & cooldown affected by talent (time to activate)
	},
	[207684] = { -- Sigil of Misery
		cooldown = 60,
		duration = 2,
		spec = SPEC_VENGEANCE
		-- TODO: Duration & cooldown affected by talent (time to activate)
	},

	-- Talents
	[207810] = { -- Nether Bond
		cooldown = 120,
		duration = 15,
		talent = true
	},
})
