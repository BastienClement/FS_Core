local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_RESTO = 264
local SPEC_ENH = 0
local SPEC_ELEM = 0

Cooldowns:RegisterSpells("SHAMAN", {
	[108280] = { -- Healing Tide Totem
		cooldown = 180,
		duration = 10,
		spec = SPEC_RESTO
	},
	[98008] = { -- Spirit Link Totem
		cooldown = 180,
		duration = 6,
		charges = function(unit)
			return unit:HasTalent(19273) and 2 or 1
		end,
		spec = SPEC_RESTO
	},
	[114052] = { -- Ascendance
		cooldown = 180,
		duration = 15,
		spec = SPEC_RESTO
	},
	[8143] = { -- Tremor Totem
		cooldown = 60,
		duration = 10
	},
	[108281] = { -- Ancestral Guidance
		cooldown = 120,
		duration = 10,
		talent = 19269
	},
})
