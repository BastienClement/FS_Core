local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BALANCE = 102
local SPEC_FERAL = 103
local SPEC_GUARDIAN = 104
local SPEC_RESTORATION = 105

Cooldowns:RegisterSpells("DRUID", {
	[106898] = { -- Stampeding Roar
		cooldown = 120,
		duration = 8,
		alias = 77761, -- Bear
		spec = { SPEC_FERAL, SPEC_GUARDIAN }
		-- TODO: Bear have less cooldown with talent (-50%)
	},

	-- Balance
	[78675] = { -- Solar Beam
		cooldown = 60,
		duration = 8,
		spec = SPEC_BALANCE
	},

	-- Guardian
	[99] = { -- Incapacitating Roar
		cooldown = 30,
		duration = 3,
		spec = SPEC_GUARDIAN
	},

	-- Resto
	[740] = { -- Tranquility
		cooldown = 180,
		duration = 8,
		spec = SPEC_RESTORATION
		-- TODO: Check artifact
	},
	[102342] = { -- Ironbark
		cooldown = 90,
		duration = 12,
		spec = SPEC_RESTORATION
		-- TODO: Affected by talent
	},

	-- Shared
	[29166] = { -- Innervate
		cooldown = 180,
		duration = 10,
		spec = { SPEC_BALANCE, SPEC_RESTORATION },
	},
	[106839] = { -- Skull Bash
		cooldown = 15,
		duration = 4,
		spec = { SPEC_GUARDIAN, SPEC_FERAL }
	},

	-- Talents
	[33891] = { -- Incarnation: Tree of Life
		cooldown = 180,
		duration = 30,
		talent = true
	},
	[102793] = { -- Ursol's Vortex
		cooldown = 60,
		duration = 10,
		talent = true
	},
	[102359] = { -- Mass Entanglement
		cooldown = 30,
		duration = 20,
		talent = true
	},
	[132469] = { -- Typhoon
		cooldown = 30,
		duration = 6,
		talent = true
	},
})
