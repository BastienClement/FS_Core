local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ASSASSINATION = 259
local SPEC_OUTLAW = 260
local SPEC_SUBTLETY = 261

Cooldowns:RegisterSpells("ROGUE", {
	[1766] = { -- Kick
		cooldown = 15,
		duration = 5
	},
	[2983] = { -- Sprint
		cooldown = 60,
		duration = 8
	},
	[31224] = { -- Clock of Shadows
		cooldown = 90,
		duration = 5
	},
	[76577] = { -- Smoke Bomb
		cooldown = 180,
		duration = 5
	},
})
