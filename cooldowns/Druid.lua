local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BALANCE = 102
local SPEC_FERAL = 103
local SPEC_GUARDIAN = 104
local SPEC_RESTORATION = 105

local function GutturalRoars(unit) return unit:HasTalentSpell(204012) and 0.5 or 1.0 end
local function InnerPeace(unit) return unit:HasTalentSpell(197073) and 60 or 0 end
local function Stonebark(unit) return unit:HasTalentSpell(197061) and 30 or 0 end
local function SurvivalOfTheFittest(unit) return unit:HasTalentSpell(203965) and 2/3 or 1 end

local function HonedInstincts(unit) return unit:GetArtifactSpellRank(210557) * 1 end
local function LightOfTheSun(unit) return unit:GetArtifactSpellRank(202918) * 15 end
local function PerpetualSpring(unit) return 1 - unit:GetArtifactSpellRank(200402) * 0.03 end
local function UrsocsEndurance(unit) return unit:GetArtifactSpellRank(200399) * 0.5 end

local function DualDeterminationCharges(unit) return unit:HasLegendary(137041) and 1 or 0 end
local function DualDeterminationCooldown(unit) return unit:HasLegendary(137041) and 1.15 or 1 end

Cooldowns:RegisterSpells("DRUID", {
	[77764] = { -- Stampeding Roar
		cooldown = function(unit) return 120 * GutturalRoars(unit) end,
		duration = 8,
		alias = 77761, -- Bear
		spec = { SPEC_FERAL, SPEC_GUARDIAN }
	},

	-- Balance
	[78675] = { -- Solar Beam
		cooldown = function(unit) return 60 - LightOfTheSun(unit) end,
		duration = 8,
		spec = SPEC_BALANCE
	},

	-- Guardian
	[99] = { -- Incapacitating Roar
		cooldown = 30,
		duration = 3,
		spec = SPEC_GUARDIAN
	},
	[22812] = { -- Barkskin
		cooldown = function(unit) return 90 * PerpetualSpring(unit) * SurvivalOfTheFittest(unit) end,
		duration = function(unit) return 12 + UrsocsEndurance(unit) end,
		duration = 12,
		spec = SPEC_GUARDIAN
	},
	[61336] = { -- Survival Instinct
		cooldown = function(unit) return 240 * SurvivalOfTheFittest(unit) / DualDeterminationCooldown(unit) end,
		duration = function(unit) return 6 + HonedInstincts(unit) end,
		charges = function(unit) return 2 + DualDeterminationCharges(unit) end,
		spec = SPEC_GUARDIAN
	},

	-- Resto
	[740] = { -- Tranquility
		cooldown = function(unit) return 180 - InnerPeace(unit) end,
		duration = 7,
		spec = SPEC_RESTORATION
	},
	[102342] = { -- Ironbark
		cooldown = function(unit) return 90 - Stonebark(unit) end,
		duration = 12,
		spec = SPEC_RESTORATION
	},
	[102793] = { -- Ursol's Vortex
		cooldown = 60,
		duration = 10,
		spec = SPEC_RESTORATION
	},

	-- Shared
	[29166] = { -- Innervate
		cooldown = 180,
		duration = 10,
		spec = { SPEC_BALANCE, SPEC_RESTORATION },
	},
	[106839] = { -- Skull Bash
		cooldown = 15,
		duration = 4,
		spec = { SPEC_GUARDIAN, SPEC_FERAL }
	},

	-- Talents
	[33891] = { -- Incarnation: Tree of Life
		cooldown = 180,
		duration = 30,
		talent = true
	},
	[102359] = { -- Mass Entanglement
		cooldown = 30,
		duration = 20,
		talent = true
	},
	[61391] = { -- Typhoon
		cooldown = 30,
		duration = 6,
		talent = 18577,
		icon = 236170
	},
})
