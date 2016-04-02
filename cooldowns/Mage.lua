local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ARCANE = 62
local SPEC_FIRE = 63
local SPEC_FROST = 64

Cooldowns:RegisterSpells("MAGE", {
	[45438] = { -- Ice block
		cooldown = 300,
		duration = 10
	},
	[1953] = { -- Blink
		cooldown = 15
	},
	[2139] = { -- Counterspell
		cooldown = 24
	},
	[80353] = { -- Time Warp
		cooldown = 300,
		duration = 40
		-- TODO: Alias to Bloodlust ?
	},

	-- Arcane
	[12042] = { -- Arcane Power
		cooldown = 90,
		duration = 10,
		spec = SPEC_ARCANE,
		disabled = true
	},
	[195676] = { -- Displacement
		cooldown = 30,
		spec = SPEC_ARCANE
		-- Teleports you back to where you last Blinked from and resets the
		-- cooldown on Blink. Only usabel within 10 sec of Blinking
	},
	[12051] = { -- Evocation
		cooldown = 90,
		duration = 6,
		spec = SPEC_ARCANE,
		disabled = true
	},
	[110959] = { -- Greater Invisibility
		cooldown = 120,
		duration = 20,
		spec = SPEC_ARCANE
	},

	-- Flame
	[190319] = { -- Combution
		cooldown = 120,
		duration = 10,
		spec = SPEC_FIRE
	},
	[31661] = { -- Dragon's Breath
		cooldown = 20,
		duration = 4,
		spec = SPEC_FIRE
	},

	-- Frost
	[120] = { -- Cone of Cold
		cooldown = 12,
		duration = 5,
		spec = SPEC_FROST
	},
	[84714] = { -- Frozen Orb
		cooldown = 60,
		duration = 10,
		spec = SPEC_FROST
	},
	[12472] = { -- Icy Veins
		cooldown = 180,
		duration = 20,
		spec = SPEC_FROST,
		disabled = true
	},

	-- Shared
	[66] = { -- Invisibility
		cooldown = 300,
		duration = 20,
		spec = { SPEC_FIRE, SPEC_FROST }
	},
})
