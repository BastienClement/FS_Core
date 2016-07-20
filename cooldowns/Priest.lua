local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_DISCIPLINE = 256
local SPEC_HOLY = 257
local SPEC_SHADOW = 258

Cooldowns:RegisterSpells("PRIEST", {
	-- Discipline
	[62618] = { -- Power Word: Barrier
		cooldown = 180,
		duration = 10,
		spec = SPEC_DISCIPLINE
	},
	[33206] = { -- Pain Suppression
		cooldown = 180, -- Legion: 5 min
		duration = 8,
		spec = SPEC_DISCIPLINE
	},
	[47536] = { -- Rapture
		cooldown = 120,
		duration = 8,
		spec = SPEC_DISCIPLINE
	},

	-- Holy
	[64843] = { -- Divine Hymn
		cooldown = 180,
		duration = 8,
		spec = SPEC_HOLY
	},
	[47788] = { -- Guardian Spirit
		cooldown = 240,
		duration = 10,
		spec = SPEC_HOLY
	},
	[88625] = { -- Chastise
		cooldown = 60,
		duration = 5,
		spec = SPEC_HOLY
	},
	[34861] = { -- Holy Word: Sanctify
		cooldown = 60,
		spec = SPEC_HOLY
	},
	[2050] = { -- Holy Word: Serenity
		cooldown = 60,
		spec = SPEC_HOLY,
		legion = true
	},

	-- Shadow
	[15286] = { -- Vampiric Embrace
		cooldown = 180,
		duration = 15,
		spec = SPEC_SHADOW
	},
	[47585] = { -- Dispersion
		cooldown = 47585,
		duration = 6,
		spec = SPEC_SHADOW
	},
	[213634] = { -- Purify Disease
		cooldown = 8,
		spec = SPEC_SHADOW
	},
	[15487] = { -- Silence
		cooldown = 45,
		duration = 3,
		spec = SPEC_SHADOW
	},

	-- Shared
	[73325] = { -- Leap of Faith
		cooldown = 90,
		spec = { SPEC_DISCIPLINE, SPEC_HOLY }
	},
	[8122] = { -- Psychic Scream
		cooldown = 60,
		duration = 8,
		spec = { SPEC_DISCIPLINE, SPEC_SHADOW }
	},
	[527] = { -- Purify
		cooldown = 8,
		spec = { SPEC_DISCIPLINE, SPEC_HOLY }
	},
	[34433] = { -- Shadowfiend
		cooldown = 180,
		duration = 12,
		spec = { SPEC_DISCIPLINE, SPEC_SHADOW },
		disabled = true
	},

	-- Talents
	[200183] = { -- Apotheosis
		cooldown = 180,
		duration = 30,
		talent = true
	},
	[10060] = { -- Power Infusion
		cooldown = 120,
		duration = 20,
		talent = true
	},
	[204263] = { -- Shining Force
		cooldown = 60,
		duration = 3,
		talent = true
	},
	[193223] = { -- Surrender to Madness
		cooldown = 600,
		talent = true
	},
	[64901] = { -- Symbol of Hope
		cooldown = 360,
		duration = 10,
		talent = true,
		legion = true
	},
	[205369] = { -- Mind Bomb
		cooldown = 30,
		duration = 4,
		-- Replaces Psychic Scream
		talent = true
	},
})
