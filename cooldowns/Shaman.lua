local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ELEMENTAL = 262
local SPEC_ENHANCEMENT = 263
local SPEC_RESTORATION = 264

Cooldowns:RegisterSpells("SHAMAN", {
	[8143] = { -- Tremor Totem
		cooldown = 60,
		duration = 10,
		legion = false
	},
	[108271] = { -- Astral Shift
		cooldown = 90,
		duration = 6
	},
	[20608] = { -- Reincarnation
		cooldown = 1800,
		reset = false,
		nocheck = true
	},
	[2825] = { -- Bloodlust
		cooldown = 300,
		duration = 40,
		alias = 32182 -- Heroism
	},
	[57994] = { -- Wind Shear
		cooldown = 12,
		duration = 3
	},

	-- ELemental
	[198103] = { -- Earth Elemental
		cooldown = 120,
		duration = 15,
		spec = SPEC_ELEMENTAL
	},
	[198067] = { -- Fire Elemental
		cooldown = 300,
		duration = 60,
		spec = SPEC_ELEMENTAL
	},
	[51490] = { -- Thunderstorm
		cooldown = 45,
		duration = 5,
		spec = SPEC_ELEMENTAL
	},

	-- Enhancement
	[51533] = { -- Feral Spirit
		cooldown = 120,
		duration = 15,
		spec = SPEC_ENHANCEMENT
	},
	[58875] = { -- Spirit Walk
		cooldown = 60,
		duration = 15,
		spec = SPEC_ENHANCEMENT
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
		charges = function(unit)
			return unit:HasTalent(19273) and 2 or 1
		end,
		spec = SPEC_RESTORATION
	},
	[114052] = { -- Ascendance
		cooldown = 180,
		duration = 15,
		spec = SPEC_RESTORATION
	},
	[5394] = { -- Healing Stream Totem
		cooldown = 30,
		duration = 15,
		charges = 1,
		spec = SPEC_RESTORATION
	},
	[77130] = { -- Purify Spirit
		cooldown = 8,
		spec = SPEC_RESTORATION
	},
	[79206] = { -- Spiritwalker's Grace
		cooldown = 120,
		duration = 15,
		spec = SPEC_RESTORATION
	},

	-- Shared
	[51886] = { -- Cleanse Spirit
		cooldown = 8,
		spec = { SPEC_ELEMENTAL, SPEC_ENHANCEMENT }
	},

	-- Talents
	[108281] = { -- Ancestral Guidance
		cooldown = 120,
		duration = 10,
		talent = 19269
	},
	[207399] = { -- Ancestral Protection Totem
		cooldown = 300,
		duration = 30,
		-- TODO: stop duration on first death
		talent = true
	},
	[198838] = { -- Earthen Shield otem
		cooldown = 60,
		duration = 15,
		talent = true
	},
	[51485] = { -- Earthgrab Totem
		cooldown = 30,
		duration = 20,
		talent = true
	},
	[197214] = { -- Sundering
		cooldown = 40,
		talent = true
	},
	[192077] = { -- Wind Rush Totem
		cooldown = 120,
		duration = 15,
		talent = true
	},
})
