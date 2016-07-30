local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_BLOOD = 250
local SPEC_FROST = 251
local SPEC_UNHOLY = 252

Cooldowns:RegisterSpells("DEATHKNIGHT", {
	[49576] = { -- Death Grip
		cooldown = function(unit)
			if unit.global_spec_id == SPEC_BLOOD then
				return 15
			else
				return 25
			end
		end,
		duration = 3
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
	[55233] = { -- Vampiric Blood
		cooldown = 90,
		duration = 10,
		spec = SPEC_BLOOD
		-- TODO: Affected by talent / item
	},
	[49028] = { -- Dancing Rune Weapon
		cooldown = 180,
		duration = 8,
		spec = SPEC_BLOOD
		-- TODO: Affected by artifact
	},

	-- Talents
	[194679] = { -- Rune Tap
		cooldowns = 25,
		duration = 3,
		charges = 2,
		talent = true
	},
	[206977] = { -- Blood Mirror
		cooldowns = 120,
		duration = 10,
		talent = true
	},
	[207319] = { -- Corpse Shield
		cooldown = 60,
		duration = 10,
		talent = true
	},
})
