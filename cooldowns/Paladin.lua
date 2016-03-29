local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HOLY = 65
local SPEC_PROT = 0
local SPEC_RET  = 0

local function Clemency(unit)
	return unit:HasTalent(17593) and 2 or 1
end

local function UnbreakableSpirit(base)
	return function(unit)
		local base_cooldown = type(base) == "function" and base(unit) or base
		return unit:HasTalent(17591) and (base_cooldown / 2) or base_cooldown
	end
end

Cooldowns:RegisterSpells("PALADIN", {
	--
	-- Shared
	--
	[498] = { -- Divine Protection
		cooldown = UnbreakableSpirit(60),
		duration = 8
	},
	[642] = { -- Divine Shield
		cooldown = UnbreakableSpirit(300),
		duration = 8,
		tag = "IMMUNE"
	},
	[1044] = { -- Hand of Freedom
		cooldown = 25,
		duration = 6,
		charges = Clemency
	},
	[1022] = { -- Hand of Protection
		cooldown = 300,
		duration = 10,
		charges = Clemency
	},
	[6940] = { -- Hand of Sacrifice
		cooldown = 120,
		duration = 12,
		charges = Clemency,
	},

	--
	-- Holy
	--
	[31842] = { -- Avenging Wrath (Holy)
		cooldown = function(unit)
			return unit:HasGlyph(162604) and 90 or 180
		end,
		duration = function(unit)
			return unit:HasTalent(17599) and 30 or 20
		end,
		spec = SPEC_HOLY,
		reset = true
	},
	[31821] = { -- Devotion Aura
		cooldown = 180,
		duration = 6,
		spec = SPEC_HOLY
	},
	[114039] = { -- Hand of Purity
		cooldown = 30,
		duration = 6,
		talent = 17589,
	},
})
