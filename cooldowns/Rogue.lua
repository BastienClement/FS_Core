local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ASSASSINATION = 259
local SPEC_OUTLAW = 260
local SPEC_SUBTLETY = 261

local function FadeIntoShadows(unit) return unit:GetArtifactSpellRank(192323) * 3 end

Cooldowns:RegisterSpells("ROGUE", {
	[1766] = { -- Kick
		cooldown = 15,
		duration = 5
	},
	[31224] = { -- Clock of Shadows
		cooldown = function(unit) return 90 - FadeIntoShadows(unit) end,
		duration = 5
	},
	[5277] = { -- Evasion
		cooldown = 120,
		duration = 5,
		alias = 199754
	},
})
