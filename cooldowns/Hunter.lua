local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BEASTMASTERY = 253
local SPEC_MARKSMANSHIP = 254
local SPEC_SURVIVAL = 255

local SPEC_RANGED = { SPEC_BEASTMASTERY, SPEC_MARKSMANSHIP }

local function EmbraceOfTheAspects(unit) return 1 - unit:GetArtifactSpellRank(225092) * 0.2 end

Cooldowns:RegisterSpells("HUNTER", {
	[186265] = { -- Aspect of the Turtle
		cooldown = function(unit) return 180 * EmbraceOfTheAspects(unit) end,
		duration = 8
	},

	-- Survival
	[187707] = { -- Muzzle
		cooldown = 15,
		duration = 3,
		spec = SPEC_SURVIVAL
	},

	-- Shared
	[147362] = { -- Counter Shot
		cooldown = 24,
		duration = 3,
		spec = SPEC_RANGED
	},

	-- Talents
	[109248] = { -- Binding Shot
		cooldown = 45,
		duration = 10,
		talent = true
	},
})
