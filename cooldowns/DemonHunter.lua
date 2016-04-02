local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HAVOC = 577
local SPEC_VENGEANCE = 581

Cooldowns:RegisterSpells("DEMONHUNTER", {
	[188499] = { -- Blur
		cooldown = 60,
		duration = 10,
	},
	[179057] = { -- Chaos Nova
		cooldown = 60,
		duration = 5,
	},
	[183752] = { -- Consume Magic
		cooldown = 20,
		duration = 3,
		alias = 183782 -- Wowhead ?!
	},

	[191427] = { -- Metamorphosis
		cooldown = 300,
		duration = 30,
	},

	-- Vengeance
	[187827] = { -- Metamorphosis
		cooldown = 180,
		duration = 20,
		spec = SPEC_VENGEANCE
	},
	[203720] = { -- Demon Spikes
		cooldown = 15,
		duration = 6,
		charges = 2,
		spec = SPEC_VENGEANCE
	},
	[218256] = { -- Empower Wards
		cooldown = 30,
		duration = 6,
		spec = SPEC_VENGEANCE
	},
	[204021] = { -- Fiery Brand
		cooldown = 60,
		duration = 8,
		spec = SPEC_VENGEANCE
	},
	[178740] = { -- Immolation Aura
		cooldown = 15,
		duration = 6,
		spec = SPEC_VENGEANCE
	},
	[189110] = { -- Infernal Strike
		cooldown = 20,
		charges = 2,
		spec = SPEC_VENGEANCE
	},
	[202138] = { -- Sigil of Chains
		cooldown = 120,
		duration = 2,
		spec = SPEC_VENGEANCE
	},
	[204596] = { -- Sigil of Flame
		cooldown = 30,
		duration = 2,
		spec = SPEC_VENGEANCE
	},
	[202137] = { -- Sigil of Silence
		cooldown = 60,
		duration = 2,
		spec = SPEC_VENGEANCE
	},
	[185245] = { -- Torment (Taunt)
		cooldown = 8,
		duration = 3,
		spec = SPEC_VENGEANCE
	},
})
