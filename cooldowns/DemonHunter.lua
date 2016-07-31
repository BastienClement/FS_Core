local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HAVOC = 577
local SPEC_VENGEANCE = 581

local function QuickenedSigils(unit) return unit:HasTalentSpell(209281) and 0.8 or 1.0 end
local function ConcentratedSigils(unit) return unit:HasTalentSpell(207666) and 2 or 0 end
local function UnleasedPower(unit) return unit:HasTalentSpell(206477) and 20 or 0 end

Cooldowns:RegisterSpells("DEMONHUNTER", {
	[196718] = { -- Darkness
		cooldown = 180,
		duration = 8,
	},
	[183752] = { -- Consume Magic
		cooldown = 15,
		duration = 3,
	},

	-- Havoc
	[179057] = { -- Chaos Nova
		cooldown = function(unit) return 60 - UnleasedPower(unit) end,
		duration = 5,
		spec = SPEC_HAVOC,
		icon = 135795
		-- TODO: Consuming orbs reduces CD
	},
	[212800] = { -- Blur
		cooldown = 60,
		duration = 10,
		spec = SPEC_HAVOC,
		icon = 1305150,
		available = function(unit)
			return (not unit:HasTalent(21863)) and (not unit:HasTalent(21864))
		end,
		enabled = false
		-- BROKEN: no combat log event on cast
	},

	-- Vengeance
	[202138] = { -- Sigil of Chains
		cooldown = function(unit) return 120 * QuickenedSigils(unit) end,
		spec = SPEC_VENGEANCE
	},
	[202137] = { -- Sigil of Silence
		cooldown = function(unit) return 60 * QuickenedSigils(unit) end,
		spec = SPEC_VENGEANCE
	},
	[207684] = { -- Sigil of Misery
		cooldown = function(unit) return 60 * QuickenedSigils(unit) end,
		spec = SPEC_VENGEANCE
	},
	[187827] = { -- Metamorphosis
		cooldown = 180,
		duration = 15,
		spec = SPEC_VENGEANCE
	},

	-- Talents
	[207810] = { -- Nether Bond
		cooldown = 120,
		duration = 15,
		talent = true
	},
	[196555] = { -- Netherwalk
		cooldown = 90,
		duration = 5,
		talent = true
	},
})
