local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BLOOD = 250
local SPEC_FROST = 251
local SPEC_UNHOLY = 252

Cooldowns:RegisterSpells("DEATHKNIGHT", {
	[49576] = { -- Death Grip
		cooldown = 25,
		duration = 3
		-- TODO: 15 tank / 25 dps
	},
	[47528] = { -- Mind freeze
		cooldown = 15,
		duration = 3
	},
	[48707] = { -- Anti-Magic Shell
		cooldown = 60,
		duration = 5
		-- TODO: Duration affected by Item / Talents
	},

	-- Blood
	[108199] = { -- Gorefiend's Grasp
		cooldown = 180,
		spec = SPEC_BLOOD
		-- TODO: Cooldown affected by Talent
	},

	-- Talents
	[207319] = { -- Corpse Shield
		cooldown = 60,
		duration = 10,
		talent = true
	},
})
