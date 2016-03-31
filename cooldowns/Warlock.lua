local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_AFFLI = 0
local SPEC_DEMONO = 0
local SPEC_DESTRO = 264

Cooldowns:RegisterSpells("WARLOCK", {
	[104773] = { -- Unending Resolve
		cooldown = 180,
		duration = 8
	},
})
