local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ARMS = 71
local SPEC_FURY = 72
local SPEC_PROTECTION = 73

Cooldowns:RegisterSpells("WARRIOR", {
	[6552] = { -- Pummel
		cooldown = 15,
		duration = 4
	},
	[114030] = { -- Vigilance
		cooldown = 120,
		duration = 12,
		talent = 19676
	},
	[3411] = { -- Intervene
		cooldown = 30,
		duration = 10
	},
	[1719] = { -- Battle Cry
		cooldown = 60,
		duration = 5
	},
	[18499] = { -- Berserker Rage
		cooldown = 60,
		duration = 6
	},

	-- Fury
	[184364] = { -- Enraged Regenration
		cooldown = 120,
		duration = 8,
		spec = SPEC_FURY
	},

	-- Protection
	[1160] = { -- Demoralizing Shout
		cooldown = 90,
		duration = 8,
		spec = SPEC_PROTECTION
	},
	[198304] = { -- Intercept
		cooldown = 20,
		duration = 10,
		spec = SPEC_PROTECTION
	},
	[12975] = { -- Last Stand
		cooldown = 180,
		duration = 15,
		spec = SPEC_PROTECTION
	},

	-- Shared
	[97462] = { -- Rallying Cry
		-- Legion: Commanding Shout
		cooldown = 180,
		duration = 10,
		spec = { SPEC_ARMS, SPEC_FURY }
	},
	[5246] = { -- Intimidating Shout
		cooldown = 90,
		duration = 8,
		spec = { SPEC_ARMS, SPEC_FURY }
	},

	-- Talents
	[107574] = { -- Avatar
		cooldown = 90,
		duration = 20,
		talent = true
	},
	[118038] = { -- Bie by the Sword
		cooldown = 120,
		duration = 8,
		-- Replaces Defensive Stance
		talent = true
	},
	[46968] = { -- Shockwave
		cooldown = 40,
		duration = 4,
		-- Cooldown reduced by 20 sec if it strikes at least 3 target
		talent = true
	},
	[107570] = { -- Storm Bolt
		cooldown = 30,
		duration = 4,
		talent = true
	},
})
