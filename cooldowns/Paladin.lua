local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_HOLY = 65
local SPEC_PROTECTION = 66
local SPEC_RETRIBUTION  = 70

local function UnbreakableSpirit(unit) return unit:HasTalent(17575) and 0.7 or 1 end

local function BlessingsOfTheSilverHand(unit) return 1 - unit:GetArtifactSpellRank(200298) * 0.05 end
local function ProtectionOfTheLight(unit) return unit:GetArtifactSpellRank(200407) * 4 end
local function TemplarOfTheLight(unit) return unit:GetArtifactSpellRank(200311) * 2 end
local function FocusedHealing(unit) return 1 - unit:GetArtifactSpellRank(200326) * 0.1 end
local function SacrificeOfTheJust(unit) return unit:GetArtifactSpellRank(209285) * 60 end
local function UnflinchingDefense(unit) return unit:GetArtifactSpellRank(209220) * 10 end
local function ProtectorOfTheAshenBlade(unit) return 1 - unit:GetArtifactSpellRank(186944) * 0.1 end

Cooldowns:RegisterSpells("PALADIN", {
	[498] = { -- Divine Protection
		cooldown = function(unit) return 60 * UnbreakableSpirit(unit) end,
		duration = function(unit) return 8 + ProtectionOfTheLight(unit) end,
		icon = 524353,
		spec = { SPEC_HOLY, SPEC_RETRIBUTION }
	},
	[642] = { -- Divine Shield
		cooldown = function(unit) return 300 * UnbreakableSpirit(unit) end,
		duration = 8
		-- Prot Artifact makes it rechage faster with Forbearance
	},
	[633] = { -- Lay on Hands
		cooldown = function(unit) return 600 * UnbreakableSpirit(unit) * FocusedHealing(unit) end
		-- Prot Artifact makes it rechage faster with Forbearance
	},
	[1044] = { -- Blessing of Freedom
		cooldown = function(unit)
			return 25 * BlessingsOfTheSilverHand(unit)
		end,
		duration = 8
	},
	[1022] = { -- Blessing of Protection
		cooldown = function(unit) return 300 * BlessingsOfTheSilverHand(unit) * ProtectorOfTheAshenBlade(unit) end,
		duration = 10,
		icon = 135964,
		available = function(unit) return not unit:HasTalent(22433) end
		-- Prot Artifact makes it rechage faster with Forbearance
	},
	[6940] = { -- Blessing of Sacrifice
		cooldown = function(unit) return (120 - SacrificeOfTheJust(unit)) * BlessingsOfTheSilverHand(unit) end,
		duration = 12,
		spec = { SPEC_HOLY, SPEC_PROTECTION }
	},

	-- Holy
	[31842] = { -- Avenging Wrath (Holy)
		cooldown = 120,
		duration = function(unit) return unit:HasTalent(22190) and 30 or 20 end,
		spec = SPEC_HOLY
	},
	[31821] = { -- Aura Mastery
		cooldown = 180,
		duration = function(unit) return 8 + TemplarOfTheLight(unit) end,
		spec = SPEC_HOLY
	},

	-- Protection
	[86659] = { -- Guardian of Ancient King
		cooldown = 300,
		duration = 8,
		spec = SPEC_PROTECTION
	},
	[31850] = { -- Ardent Defender
		cooldown = function(unit) return 120 - UnflinchingDefense(unit) end,
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
