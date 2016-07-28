local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_AFFLICTION = 265
local SPEC_DEMONOLOGY = 266
local SPEC_DESTRUCTION = 267

Cooldowns:RegisterSpells("WARLOCK", {
	[104773] = { -- Unending Resolve
		cooldown = 180,
		duration = 8
	},

	-- Talents
	[108416] = { -- Dark Pact
		cooldown = 60,
		duration = 20,
		talent = true
	},
	[30283] = { -- Shadowfury
		cooldown = 30,
		duration = 3,
		talent = true
	},
})
