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
		alias = 77761 -- Bear
		-- LEGION: spec = { SPEC_FERAL, SPEC_GUARDIAN }
	},
	[1850] = { -- Dash
		cooldown = 180,
		duration = 15
	},
	[22812] = { -- Barkskin
		cooldown = 60,
		duration = 12
	},

	-- Balance
	[194223] = { -- Celestial Alignment
		cooldown = 180,
		duration = 15,
		spec = SPEC_BALANCE
	},
	[78675] = { -- Solar Beam
		cooldown = 60,
		duration = 8,
		spec = SPEC_BALANCE
	},

	-- Feral
	[106951] = { -- Berserk
		cooldown = 180,
		duration = 15,
		spec = SPEC_FERAL,
		disabled = true
	},
	[5217] = { -- Tiger's Fury
		cooldown = 30,
		duration = 8,
		spec = SPEC_FERAL,
		disabled = true
	},

	-- Guardian
	[22842] = { -- Frenzied Regeneration
		cooldown = 24,
		duration = 6,
		charges = 2,
		spec = SPEC_GUARDIAN
	},
	[99] = { -- Incapacitating Roar
		cooldown = 30,
		duration = 3,
		spec = SPEC_GUARDIAN
	},
	[192081] = { -- Iron Fur
		cooldown = 60,
		duration = 6,
		spec = SPEC_GUARDIAN
	},

	-- Resto
	[740] = { -- Tranquility
		cooldown = 180,
		duration = 8,
		spec = SPEC_RESTORATION
	},
	[33891] = { -- Incarnation: Tree of Life
		cooldown = 180,
		duration = 30,
		talent = 21707
	},
	[102342] = { -- Ironbark
		cooldown = 60, -- Legion: 90
		duration = 12,
		spec = SPEC_RESTORATION
	},
	[124974] = { -- Nature's Vigil
		cooldown = 90,
		duration = 30,
		talent = 18586
	},
	[88423] = { -- Nature's Cure
		cooldown = 8,
		spec = SPEC_RESTORATION
	},
	[18562] = { -- Swiftmend
		cooldown = 30,
		spec = SPEC_RESTORATION,
		disabled = true
	},
	[102793] = { -- Ursol's Vortex
		cooldown = 60,
		duration = 10,
		spec = SPEC_RESTORATION
	},
	[48438] = { -- Wild Growth
		cooldown = 10,
		duration = 7,
		spec = SPEC_RESTORATION,
		disabled = true
	},

	-- Shared
	[29166] = { -- Innervate
		cooldown = 180,
		duration = 10,
		spec = { SPEC_BALANCE, SPEC_RESTORATION },
		legion = true
	},
	[2782] = { -- Remove Corruption
		cooldown = 8,
		spec = { SPEC_GUARDIAN, SPEC_BALANCE, SPEC_FERAL }
	},
	[106839] = { -- Skull Bash
		cooldown = 15,
		duration = 4,
		spec = { SPEC_GUARDIAN, SPEC_FERAL }
	},
	[61336] = { -- Survival Instincts
		cooldown = 180,
		duration = 6,
		charges = 2,
		spec = { SPEC_FERAL, SPEC_GUARDIAN }
	},
})
