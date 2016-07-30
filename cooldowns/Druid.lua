local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BALANCE = 102
local SPEC_FERAL = 103
local SPEC_GUARDIAN = 104
local SPEC_RESTORATION = 105

Cooldowns:RegisterSpells("DRUID", {
	[77764] = { -- Stampeding Roar
		cooldown = function(unit) return unit:HasTalent(22424) and 60 or 120 end,
		duration = 8,
		alias = 77761, -- Bear
		spec = { SPEC_FERAL, SPEC_GUARDIAN }
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
	[22812] = { -- Barkskin
		cooldown = 60,
		duration = 12,
		spec = SPEC_GUARDIAN
	},
	[61336] = { -- Survival Instinct
		cooldown = 180,
		duration = 6,
		charges = 2,
		spec = SPEC_GUARDIAN
	},

	-- Resto
	[740] = { -- Tranquility
		cooldown = 180,
		duration = 7,
		spec = SPEC_RESTORATION
	},
	[102342] = { -- Ironbark
		cooldown = function(unit) return unit:HasTalent(21651) and 60 or 90 end,
		duration = 12,
		spec = SPEC_RESTORATION
	},
	[102793] = { -- Ursol's Vortex
		cooldown = 60,
		duration = 10,
		spec = SPEC_RESTORATION
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
	[102359] = { -- Mass Entanglement
		cooldown = 30,
		duration = 20,
		talent = true
	},
	[61391] = { -- Typhoon
		cooldown = 30,
		duration = 6,
		talent = 18577,
		icon = 236170
	},
})
