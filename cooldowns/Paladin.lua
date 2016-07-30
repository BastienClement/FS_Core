local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HOLY = 65
local SPEC_PROTECTION = 66
local SPEC_RETRIBUTION  = 70


local function UnbreakableSpirit(base)
	return function(unit)
		local base_cooldown = type(base) == "function" and base(unit) or base
		return unit:HasTalent(17575) and (base_cooldown * 0.7) or base_cooldown
	end
end

Cooldowns:RegisterSpells("PALADIN", {
	[498] = { -- Divine Protection
		cooldown = UnbreakableSpirit(60),
		duration = 8,
		icon = 524353,
		spec = { SPEC_HOLY, SPEC_RETRIBUTION }
		-- Holy Artifact inscreses the duration by 4 sec
	},
	[642] = { -- Divine Shield
		cooldown = UnbreakableSpirit(300),
		duration = 8
		-- Prot Artifact makes it rechage faster with Forbearance
	},
	[633] = { -- Lay on Hands
		cooldown = UnbreakableSpirit(600)
		-- TODO: Broken ?
		-- Holy Artifact reduces cooldown by 30%
		-- Prot Artifact makes it rechage faster with Forbearance
	},
	[1044] = { -- Blessing of Freedom
		cooldown = 25,
		duration = 6
		-- Holy Artifact reduces cooldown by 15%
	},
	[1022] = { -- Blessing of Protection
		cooldown = 300,
		duration = 10,
		icon = 135964,
		available = function(unit) return not unit:HasTalent(22433) end
		-- Holy Artifact reduces cooldown by 15%
		-- Prot Artifact makes it rechage faster with Forbearance
		-- Retribution Artifact reduces cooldown by 30%
	},
	[6940] = { -- Blessing of Sacrifice
		cooldown = 120,
		duration = 12,
		spec = { SPEC_HOLY, SPEC_PROTECTION }
		-- Holy Artifact reduces cooldown by 15%
		-- Prot Artifact reduces cooldown by 60 sec
	},

	-- Holy
	[31842] = { -- Avenging Wrath (Holy)
		cooldown = 120,
		duration = function(unit)
			return unit:HasTalent(22190) and 30 or 20
		end,
		spec = SPEC_HOLY
	},
	[31821] = { -- Aura Mastery
		cooldown = 180,
		duration = 8,
		spec = SPEC_HOLY
		-- Holy Artifact increases duration by 2 sec
	},

	-- Protection
	[86659] = { -- Guardian of Ancient King
		cooldown = 300,
		duration = 8,
		spec = SPEC_PROTECTION
	},
	[31850] = { -- Ardent Defender
		cooldown = 120,
		duration = 8,
		spec = SPEC_PROTECTION
	},

	-- Shared
	[96231] = { -- Rebuke
		cooldown = 15,
		duration = 4,
		spec = { SPEC_PROTECTION, SPEC_RETRIBUTION }
	},

	-- Talents
	[204150] = { -- Aegis of Light
		cooldown = 300,
		duration = 6,
		talent = true
	},
	[204018] = { -- Blessing of Spellwarding
		cooldown = 180,
		duration = 10,
		talent = true
		-- Prot Artifact makes it rechage faster with Forbearance
	},
	[105809] = { -- Holy Avenger
		cooldown = 90,
		duration = 20,
		talent = true
	},
})
