local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BEASTMASTERY = 253
local SPEC_MARKSMANSHIP = 254
local SPEC_SURVIVAL = 255

local SPEC_RANGED = { SPEC_BEASTMASTERY, SPEC_MARKSMANSHIP }

Cooldowns:RegisterSpells("HUNTER", {
	[5384] = { -- Feign Death
		cooldown = 30
	},
	[186265] = { -- Aspect of the Turtle
		cooldown = 180,
		duration = 8
	},
	[194291] = { -- Exhilaration
		cooldown = 120,
		alias = 109304
	},

	-- Beast Mastery
	[193530] = { -- Aspect of the Wild
		cooldown = 120,
		duration = 10,
		spec = SPEC_BEASTMASTERY
	},
	[19574] = { -- Bestial Wrath
		cooldown = 90,
		duration = 10,
		spec = SPEC_BEASTMASTERY
		-- TODO: cooldown is reduced by 15 each time you use Dire Beast / Dire Frenzy
	},
	[120679] = { -- Dire Beast
		cooldown = 12,
		duration = 8,
		spec = SPEC_BEASTMASTERY,
		hidden = true
	},

	-- Marksmanship
	[186387] = { -- Bursting Shot
		cooldown = 30,
		duration = 4,
		spec = SPEC_MARKSMANSHIP
	},
	[193526] = { -- Trueshot
		cooldown = 180,
		duration = 15,
		spec = SPEC_MARKSMANSHIP
	},

	-- Survival
	[186289] = { -- Aspect of the Eagle
		cooldown = 120,
		duration = 10,
		spec = SPEC_SURVIVAL
	},
	[191433] = { -- Explosive Trap
		cooldown = 30,
		spec = SPEC_SURVIVAL
	},
	[187650] = { -- Freezing Trap
		cooldown = 30,
		spec = SPEC_SURVIVAL
	},
	[187698] = { -- Tar Trap
		cooldown = 30,
		spec = SPEC_SURVIVAL
	},
	[190925] = { -- Harpoon
		cooldown = 20,
		duration = 3,
		spec = SPEC_SURVIVAL
	},
	[187707] = { -- Muzzle
		cooldown = 15,
		duration = 3,
		spec = SPEC_SURVIVAL
	},

	-- Shared
	[147362] = { -- Counter Shot
		cooldown = 24,
		duration = 3,
		spec = SPEC_RANGED
	},
	[781] = { -- Disengage
		cooldown = 20,
		duration = 8,
		spec = SPEC_RANGED
	},
	[34477] = { -- Misdirection
		cooldown = 30,
		duration = 8,
		spec = SPEC_RANGED
	},

	-- Talents
	[109248] = { -- Binding Shot
		cooldown = 45,
		duration = 10,
		talent = true
	},
	[19577] = { -- Intimidation
		cooldown = 60,
		duration = 5,
		talent = true
	},
	[200108] = { -- Ranger's Net
		cooldown = 60,
		duration = 3,
		talent = true
	},
	[191241] = { -- Sticky Bomb
		cooldown = 30,
		duration = 3,
		talent = true
	},
})
