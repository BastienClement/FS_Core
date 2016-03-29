local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HOLY = 65
local SPEC_PROT = 0
local SPEC_RET  = 0

Cooldowns:RegisterSpells("PALADIN", {
	--
	-- Shared
	--
	[4987] = { -- Cleanse
		cooldown = 8,
	},
	[498] = { -- Divine Protection
		cooldown = 30,
		duration = 8
	},
	[642] = { -- Divine Shield
		cooldown = 300,
		duration = 8,
		tag = "IMMUNE"
	},
	[105593] = { -- Fist of Justice
		cooldown = 30,
		duration = 6,
		talent = 0,
	},
	[1044] = { -- Hand of Freedom
		cooldown = 25,
		duration = 6,
	},
	[1022] = { -- Hand of Protection
		cooldown = 300,
		duration = 10,
	},
	[6940] = { -- Hand of Sacrifice
		cooldown = 120,
		duration = 12,
	},
	[633] = { -- Lay on Hands
		cooldown = 600,
	},
	[96231] = { -- Rebuke
		cooldown = 15,
		duration = 4,
	},
	[62124] = { -- Reckoning
		cooldown = 8,
		duration = 3,
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
	[20473] = { -- Holy shock
		cooldown = 6,
		charges = 2,
		spec = SPEC_HOLY
	},
})
