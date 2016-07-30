local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HAVOC = 577
local SPEC_VENGEANCE = 581

local function QuickenedSigils(base)
	return function(unit)
		return unit:HasTalent(22511) and (base * 0.8) or base
	end
end

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
		cooldown = 60,
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
		cooldown = QuickenedSigils(120),
		spec = SPEC_VENGEANCE
	},
	[202137] = { -- Sigil of Silence
		cooldown = QuickenedSigils(60),
		spec = SPEC_VENGEANCE
	},
	[207684] = { -- Sigil of Misery
		cooldown = QuickenedSigils(60),
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
