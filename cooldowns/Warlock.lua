local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_AFFLICTION = 265
local SPEC_DEMONOLOGY = 266
local SPEC_DESTRUCTION = 267

local function DemonicDurability(unit) return unit:GetArtifactSpellRank(215223) * 30 end
local function FirmResolve(unit) return unit:GetArtifactSpellRank(211131) * 10 end

Cooldowns:RegisterSpells("WARLOCK", {
	[104773] = { -- Unending Resolve
		cooldown = function(unit) return 180 - DemonicDurability(unit) - FirmResolve(unit) end,
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
