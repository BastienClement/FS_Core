local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BREWMASTER = 268
local SPEC_WINDWALKER = 269
local SPEC_MISTWEAVER = 270

Cooldowns:RegisterSpells("MONK", {
	[119996] = { -- Transcendence: Transert
		cooldown = 25
	},

	-- Brewmaster
	[115181] = { -- Breath of Fire
		cooldown = 15,
		duration = 8,
		spec = SPEC_BREWMASTER
	},
	[115203] = { -- Fortifying Brew
		cooldown = 300,
		duration = 15,
		spec = SPEC_BREWMASTER
	},
	[115308] = { -- Ironskin Brew
		cooldown = 14,
		duration = 6,
		charges = 3,
		spec = SPEC_BREWMASTER
		-- Shares charges with Purifying Brew
	},
	[119582] = { -- Purifying Brew
		cooldown = 14,
		charges = 3,
		spec = SPEC_BREWMASTER
		-- Shares charges with Ironskin Brew
	},
	[121253] = { -- Keg Smash
		cooldown = 8,
		spec = SPEC_BREWMASTER,
		hidden = true
		-- Reduces the remaining cooldown on your Brews by 4 sec.
	},
	[115176] = { -- Zen Meditation
		cooldown = 300,
		duration = 8,
		spec = SPEC_BREWMASTER
	},

	-- Windwalker
	[113656] = { -- Fists of Fury
		cooldown = 24,
		duration = 4,
		spec = SPEC_WINDWALKER,
		disabled = true
	},
	[101545] = { -- Flying Serpent Kick
		cooldown = 25,
		duration = 2,
		spec = SPEC_WINDWALKER
	},
	[116740] = { -- Tigereye Brew
		cooldown = 90,
		duration = 15,
		charges = 2,
		spec = SPEC_WINDWALKER,
		disabled = true
	},
	[115080] = { -- Touch of Death
		cooldown = 120,
		duration = 8,
		spec = SPEC_WINDWALKER
	},
	[122470] = { -- Touch of Karma
		cooldown = 90,
		duration = 10,
		spec = SPEC_WINDWALKER
	},

	-- Mistsweaver
	[115310] = { -- Revival
		cooldown = 180,
		spec = SPEC_MISTWEAVER
	},
	[116849] = { -- Life Cocoon
		cooldown = 100, -- Legion: 180
		duration = 12,
		spec = SPEC_MISTWEAVER
	},
	[115450] = { -- Detox
		cooldown = 8,
		spec = SPEC_MISTWEAVER
	},

	-- Shared
	[218164] = { -- Detox
		cooldown = 8,
		spec = { SPEC_BREWMASTER, SPEC_WINDWALKER }
	},
	[116705] = { -- Spear Hand Strike
		cooldown = 15,
		duration = 4,
		spec = { SPEC_BREWMASTER, SPEC_WINDWALKER }
	},

	-- Talents
	[122278] = { -- Dampen Harm
		cooldown = 120,
		talent = true
	},
	[122783] = { -- Diffuse Magic
		cooldown = 120,
		duration = 6,
		talent = true
	},
	[198664] = { -- Invoke Chi-Ji, the Red Crane
		cooldown = 180,
		duration = 45,
		talent = true
	},
	[132578] = { -- Invoke Niuzao, the Black Ox
		cooldown = 180,
		duration = 45,
		talent = true
	},
	[119381] = { -- Leg Sweep
		cooldown = 45,
		duration = 5,
		talent = true
	},
	[197908] = { -- Mana Tea
		cooldown = 90,
		duration = 10,
		talent = true
	},
	[197945] = { -- Mistwalk
		cooldown = 20,
		talent = true
	},
	[116844] = { -- Ring of Peave
		cooldown = 45,
		duration = 8,
		talent = true
	},
	[152173] = { -- Serenity
		cooldown = 90,
		duration = 10,
		talent = true
	},
	[198898] = { -- Song of Chi-Ji
		cooldown = 30,
		talent = true
	},
	[116841] = { -- Tiger's List
		cooldown = 30,
		duration = 6,
		talent = true
	},
})
