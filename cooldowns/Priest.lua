local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_DISCIPLINE = 256
local SPEC_HOLY = 257
local SPEC_SHADOW = 258

Cooldowns:RegisterSpells("PRIEST", {
	[62618] = { -- Power Word: Barrier
		cooldown = 180,
		duration = 10,
		spec = SPEC_DISCIPLINE
	},
	[33206] = { -- Pain Suppression
		cooldown = 180,
		duration = 8,
		spec = SPEC_DISCIPLINE
	},
	[64843] = { -- Divine Hymn
		cooldown = 180,
		duration = 8,
		spec = SPEC_HOLY
	},
	[47788] = { -- Guardian Spirit
		cooldown = 180,
		duration = 10,
		spec = SPEC_HOLY
	},
	[15286] = { -- Vampiric Embrace
		cooldown = 180,
		duration = 15,
		spec = SPEC_SHADOW
	},
})
