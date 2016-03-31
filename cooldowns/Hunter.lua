local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BEAST = 0
local SPEC_MARKSMAN = 0
local SPEC_SURVIVAL = 0

Cooldowns:RegisterSpells("HUNTER", {
	[5384] = { -- Feign Death
		cooldown = 30
	},
	--[[
	[186265] = { -- Aspect of the Turtle
		cooldown = 180,
		duration = 8
	},
	]]
})
