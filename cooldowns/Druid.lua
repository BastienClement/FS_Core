local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BALANCE = 0
local SPEC_FERAL = 0
local SPEC_GUARDIAN = 0
local SPEC_RESTO = 105

Cooldowns:RegisterSpells("DRUID", {
	[106898] = { -- Stampeding Roar
		cooldown = 120,
		duration = 8,
		alias = 77761 -- Bear
	},
	[1850] = { -- Dash
		cooldown = 180,
		duration = 15
	},

	--
	-- Resto
	--
	[740] = { -- Tranquility
		cooldown = 180,
		duration = 8,
		spec = SPEC_RESTO
	},
	[33891] = { -- Incarnation: Tree of Life
		cooldown = 180,
		duration = 30,
		talent = 21707
	},
	[102342] = { -- Ironbark
		cooldown = 60,
		duration = 12,
		spec = SPEC_RESTO
	},
	[124974] = { -- Nature's Vigil
		cooldown = 90,
		duration = 30,
		talent = 18586
	},
})
