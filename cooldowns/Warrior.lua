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

	-- Protection
	[198304] = { -- Intercept
		cooldown = 15,
		duration = 6,
		charges = 2,
		spec = SPEC_PROTECTION,
		available = function(unit) return unit:HasTalent(22789) end
	},

	-- Arms
	[118038] = { -- Die by the Sword
		cooldown = 120,
		duration = 8,
		spec = SPEC_ARMS
	},

	-- Shared
	[97462] = { -- Commanding Shout
		cooldown = 180,
		duration = 10,
		spec = { SPEC_ARMS, SPEC_FURY }
	},

	-- Talent
	[46968] = { -- Shockwave
		cooldown = 40,
		duration = 4,
		talent = true
		-- TODO: Cooldown reduced by 20 sec if it strikes at least 3 target
	},
})
