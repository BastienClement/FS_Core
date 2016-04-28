local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HOLY = 65
local SPEC_PROTECTION = 66
local SPEC_RETRIBUTION  = 70

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
	[498] = { -- Divine Protection
		-- Legion: not available to Prot
		cooldown = UnbreakableSpirit(60),
		duration = 8
	},
	[642] = { -- Divine Shield
		cooldown = UnbreakableSpirit(300),
		duration = 8
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
		-- Legion: not available to Prot
		cooldown = 120,
		duration = 12,
		charges = Clemency,
	},
	[853] = { -- Hammer of Justice
		cooldown = 60,
		duration = 6
	},

	-- Holy
	[31842] = { -- Avenging Wrath (Holy)
		cooldown = function(unit)
			if Cooldowns.Legion then return 120 end
			return unit:HasGlyph(162604) and 90 or 180
		end,
		duration = function(unit)
			return unit:HasTalent(17599) and 30 or 20
		end,
		spec = SPEC_HOLY,
		reset = true
	},
	[31821] = { -- Devotion Aura
		-- Legion: Aura Mastery
		cooldown = 180,
		duration = 6,
		spec = SPEC_HOLY
	},
	[114039] = { -- Hand of Purity
		cooldown = 30,
		duration = 6,
		talent = 17589,
		legion = false
	},

	-- Protection
	[31850] = { -- Ardent Defender
		cooldown = 120,
		duration = 8,
		spec = SPEC_PROTECTION
	},
	[31935] = { -- Avenger's Shield
		cooldown = 15,
		duration = 3,
		spec = SPEC_PROTECTION
	},
	[4987] = { -- Cleanse
		cooldown = 8,
		spec = SPEC_HOLY
	},
	[190784] = { -- Divine Steed
		cooldown = 60,
		duration = 4,
		spec = SPEC_PROTECTION
	},
	[86659] = { -- Guardian of Ancient Kings
		cooldown = 300,
		duration = 8, -- TODO
		spec = SPEC_PROTECTION
	},
	[184092] = { -- Light of the Protector
		cooldown = 15,
		spec = SPEC_PROTECTION
	},
	[53600] = { -- Shield of the Righteous
		cooldown = 12,
		duration = 4.5,
		charges = 3,
		spec = SPEC_PROTECTION,
		disabled = true
	},

	-- Retribution
	[183218] = { -- Hand of Hindrance
		cooldown = 30,
		duration = 10,
		spec = SPEC_RETRIBUTION
	},
	[184662] = { -- Shield of Vemgeance
		cooldown = 120,
		duration = 15,
		spec = SPEC_RETRIBUTION
	},

	-- Shared
	[31884] = { -- Avenging Wrath (Prot / Ret)
		cooldown = 120,
		duration = 20,
		spec = { SPEC_PROTECTION, SPEC_RETRIBUTION }
	},
	[213644] = { -- Cleanse Toxins
		cooldown = 8,
		spec = { SPEC_PROTECTION, SPEC_RETRIBUTION }
	},
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
	[204013] = { -- Blessing of Salvation
		cooldown = 60,
		duration = 10,
		talent = true
	},
	[204018] = { -- Blessing of Spellwarding
		cooldown = 180,
		duration = 10,
		-- Replaces Blessing of Protection
		talent = true
	},
	[115750] = { -- Blinding Light
		cooldown = 90,
		duration = 6,
		talent = true
	},
	[205656] = { -- Divine Steed
		cooldown = 60,
		duration = 4,
		talent = true
	},
	[210220] = { -- Equality
		cooldown = 300,
		talent = true
	},
	[114158] = { -- Light's Hammer
		cooldown = 60,
		duration = 14,
		talent = true
	},
	[214202] = { -- Rule of Law
		cooldown = 30,
		charges = 2,
		duration = 10,
		talent = true
	},
	[210191] = { -- Word of Glory
		cooldown = 60,
		charges = 2,
		talent = true
	},
})
