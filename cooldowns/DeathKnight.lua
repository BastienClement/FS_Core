local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BLOOD = 0
local SPEC_FROST = 0
local SPEC_UNHOLY = 0

Cooldowns:RegisterSpells("DEATHKNIGHT", {
	[51052] = { -- Anti-Magic Zone
		cooldown = 120,
		duration = 3,
		talent = 19219
	},
	[108199] = { -- Gorefiend's Grasp
		cooldown = 60,
		talent = 19230
	},
})
