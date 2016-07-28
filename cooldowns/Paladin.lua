local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HOLY = 65
local SPEC_PROTECTION = 66
local SPEC_RETRIBUTION  = 70

--[[
local function UnbreakableSpirit(base)
	return function(unit)
		local base_cooldown = type(base) == "function" and base(unit) or base
		return unit:HasTalent(17591) and (base_cooldown / 2) or base_cooldown
	end
end
]]

Cooldowns:RegisterSpells("PALADIN", {
	[498] = { -- Divine Protection
		cooldown = 60,
		duration = 8,
		spec = { SPEC_HOLY, SPEC_RETRIBUTION }
		-- TODO: Holy has Unbreakable Spirit
	},
	[642] = { -- Divine Shield
		cooldown = 300,
		duration = 8
		-- TODO: Holy has Unbreakable Spirit
	},
	[633] = { -- Lay on Hands
		cooldown = 600
		-- TODO: Holy has Unbreakable Spirit
	},
	[1044] = { -- Blessing of Freedom
		cooldown = 25,
		duration = 6
	},
	[1022] = { -- Blessing of Protection
		cooldown = 300,
		duration = 10
		-- TODO: Replaced by Blessing of Spellwarding
	},
	[6940] = { -- Blessing of Sacrifice
		cooldown = 120,
		duration = 12,
		spec = { SPEC_HOLY, SPEC_PROTECTION }
	},

	-- Holy
	[31842] = { -- Avenging Wrath (Holy)
		cooldown = 120,
		duration = function(unit)
			return unit:HasTalent(17599) and 30 or 20
		end,
		spec = SPEC_HOLY
		-- TODO: Check talent
	},
	[31821] = { -- Aura Mastery
		cooldown = 180,
		duration = 6,
		spec = SPEC_HOLY
		-- TODO: 10 sec with Artifact
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
		-- Replaces Blessing of Protection
	},
})
