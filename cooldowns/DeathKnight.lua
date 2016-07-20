local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BLOOD = 250
local SPEC_FROST = 251
local SPEC_UNHOLY = 252

Cooldowns:RegisterSpells("DEATHKNIGHT", {
	[49576] = { -- Death Grip
		cooldown = 25,
		duration = 3
	},
	[47528] = { -- Mind freeze
		cooldown = 15,
		duration = 3
	},
	[48707] = { -- Anti-Magic Shell
		cooldown = 60,
		duration = 5
	},
	[212552] = { -- Wraith Walk
		cooldown = 60,
		duration = 3
	},

	-- Blood
	[49028] = { -- Dancing Rune Weapon
		cooldown = 180,
		duration = 8,
		spec = SPEC_BLOOD
	},
	[55233] = { -- Vampiric Blood
		cooldown = 90,
		duration = 10,
		spec = SPEC_BLOOD
	},
	[221562] = { -- Asphyxiate
		cooldown = 45,
		duration = 5,
		spec = SPEC_BLOOD
	},
	[108199] = { -- Gorefiend's Grasp
		cooldown = 180,
		spec = SPEC_BLOOD
	},

	-- Frost
	[47568] = { -- Empower Rune Weapon
		cooldown = 180,
		spec = SPEC_FROST
	},
	[196770] = { -- Remorseless Winter
		cooldown = 20,
		duration = 8,
		spec = SPEC_FROST
	},
	[51271] = { -- Pillar of Frost
		cooldown = 60,
		duration = 20,
		spec = SPEC_FROST
	},

	-- Unholy
	[42650] = { -- Army of the Dead
		cooldown = 600,
		duration = 40,
		spec = SPEC_UNHOLY
	},
	[49206] = { -- Summon Gargoyle
		cooldown = 180,
		duration = 40,
		spec = SPEC_UNHOLY
	},
	[63560] = { -- Dark Transformation
		cooldown = 60,
		duration = 20,
		spec = SPEC_UNHOLY
	},
	[46584] = { -- Raise Dead
		cooldown = 60,
		spec = SPEC_UNHOLY
	},

	-- Shared
	[43265] = { -- Death and Decay
		cooldown = 30,
		duration = 10,
		spec = { SPEC_BLOOD, SPEC_UNHOLY },
	},
	[48792] = { -- Icebound Fortitude
		cooldown = 180,
		duration = 8,
		spec = { SPEC_FROST, SPEC_UNHOLY }
	},

	-- Talents
	[207349] = { -- Dark Arbiter
		cooldown = 180,
		duration = 15,
		talent = true
	},
	[207256] = { -- Obliteration
		cooldown = 90,
		duration = 8,
		talent = true
	},
	[130736] = { -- Soul Reaper
		cooldown = 45,
		duration = 5,
		talent = true
	},
	[206977] = { -- Blood Mirror
		cooldown = 120,
		duration = 10,
		talent = true
	},
	[194679] = { -- Rune Tap
		cooldown = 25,
		duration = 3,
		talent = true
	},
	[207319] = { -- Corpse Shield
		cooldown = 60,
		duration = 10,
		talent = true
	},
	[219809] = { -- Tombstone
		cooldown = 60,
		duration = 8,
		talent = true
	},
	[108194] = { -- Asphyxiate
		cooldown = 45,
		duration = 5,
		talent = true
	},
	[207167] = { -- Blinding Sleet
		cooldown = 60,
		duration = 4,
		talent = true
	},
	[207127] = { -- Hungering Rune Weapon
		cooldown = 180,
		duration = 12,
		talent = true
	},
	[194918] = { -- Blighted Rune Weapon
		cooldown = 60,
		talent = true
	},
	[206931] = { -- Blooddrinker
		cooldown = 30,
		duration = 3,
		talent = true
	},
})
