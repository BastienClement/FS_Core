local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ELEM = 0
local SPEC_ENH = 0
local SPEC_RESTO = 264

Cooldowns:RegisterSpells("SHAMAN", {
	[8143] = { -- Tremor Totem
		cooldown = 60,
		duration = 10
	},
	[108271] = { -- Astral Shift
		cooldown = 90,
		duration = 6
	},
	[20608] = { -- Reincarnation
		cooldown = 1800
	},
	[2825] = { -- Bloodlust
		cooldown = 300,
		duration = 40,
		alias = 32182 -- Heroism
	},

	--
	-- Resto
	--
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
	[108281] = { -- Ancestral Guidance
		cooldown = 120,
		duration = 10,
		talent = 19269
	},
})
