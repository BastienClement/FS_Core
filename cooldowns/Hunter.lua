local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BEASTMASTER = 253
local SPEC_MARKMANSHIP = 254
local SPEC_SURVIVAL = 255

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
