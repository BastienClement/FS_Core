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
})
