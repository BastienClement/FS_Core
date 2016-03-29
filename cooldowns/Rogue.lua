local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ASSA = 0
local SPEC_OUTLAW = 0
local SPEC_SUB = 0

Cooldowns:RegisterSpells("ROGUE", {
	[76577] = { -- Smoke Bomb
		cooldown = 180,
		duration = 5
	},
})
