local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ELEMENTAL = 262
local SPEC_ENHANCEMENT = 263
local SPEC_RESTORATION = 264

Cooldowns:RegisterSpells("SHAMAN", {
	[108271] = { -- Astral Shift
		cooldown = 90,
		duration = 8
	},
	[20608] = { -- Reincarnation
		cooldown = 1800,
		reset = false,
		nocheck = true
	},
	[57994] = { -- Wind Shear
		cooldown = 12,
		duration = 3
	},

	-- Restoration
	[108280] = { -- Healing Tide Totem
		cooldown = 180,
		duration = 10,
		spec = SPEC_RESTORATION
	},
	[98008] = { -- Spirit Link Totem
		cooldown = 180,
		duration = 6,
		spec = SPEC_RESTORATION
	},

	-- Talents
	[114052] = { -- Ascendance
		cooldown = 180,
		duration = 15,
		talent = true
	},
	[108281] = { -- Ancestral Guidance
		cooldown = 120,
		duration = 10,
		talent = true
	},
	[207399] = { -- Ancestral Protection Totem
		cooldown = 300,
		duration = 30,
		talent = true
		-- TODO: stop duration on first death
	},
	[51485] = { -- Earthgrab Totem
		cooldown = 30,
		duration = 7,
		talent = true
	},
	[192077] = { -- Wind Rush Totem
		cooldown = 120,
		duration = 15,
		talent = true
	},
})
