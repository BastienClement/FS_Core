local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ARCANE = 0
local SPEC_FIRE = 0
local SPEC_FROST = 0

Cooldowns:RegisterSpells("MAGE", {
	[45438] = { -- Ice block
		cooldown = 300,
		duration = 10
	},
	[1953] = { -- Blink
		cooldown = 15
	},
	[2139] = { -- Counterspell
		cooldown = 24
	},
	[80353] = { -- Time Warp
		cooldown = 300,
		duration = 40
		-- TODO: Alias to Bloodlust ?
	},
})
