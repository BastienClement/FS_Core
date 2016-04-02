local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

local SPEC_ASSASSINATION = 259
local SPEC_OUTLAW = 260
local SPEC_SUBTLETY = 261

Cooldowns:RegisterSpells("ROGUE", {
	[1766] = { -- Kick
		cooldown = 15,
		duration = 5
	},
	[2983] = { -- Sprint
		cooldown = 60,
		duration = 8
	},
	[31224] = { -- Clock of Shadows
		cooldown = 90,
		duration = 5
	},
	[76577] = { -- Smoke Bomb
		cooldown = 180,
		duration = 5
	},
	[1856] = { -- Vanish
		cooldown = 120,
		duration = 3
	},

	-- Assassination
	[79140] = { -- Vendetta
		cooldown = 120,
		duration = 20,
		spec = SPEC_ASSASSINATION,
		disabled = true
	},

	-- Outlaw
	[13750] = { -- Adrenaline Rush
		cooldown = 180,
		duration = 15,
		spec = SPEC_OUTLAW,
		disabled = true
	},
	[199740] = { -- Bribe
		cooldown = 1800,
		spec = SPEC_OUTLAW
		-- TODO: dont reset on wipe ?
	},
	[1776] = { -- Gouge
		cooldown = 10,
		duration = 4,
		spec = SPEC_OUTLAW
	},
	[199754] = { -- Riposte
		cooldown = 120,
		duration = 10,
		spec = SPEC_OUTLAW
	},

	-- Subtlety
	[121471] = { -- Shadow Blades
		cooldown = 180,
		duration = 15,
		spec = SPEC_SUBTLETY,
		legion = true
	},
	[185313] = { -- Shadow Dance
		cooldown = 60,
		duration = 3,
		charges = 3,
		spec = SPEC_SUBTLETY
	},

	-- Shared
	[2094] = { -- Blind
		cooldown = 120,
		spec = { SPEC_OUTLAW, SPEC_SUBTLETY }
	},
	[5277] = { -- Evasion
		cooldown = 120,
		duration = 10,
		spec = { SPEC_ASSASSINATION, SPEC_SUBTLETY }
	},
	[36554] = { -- Shadowstep
		cooldown = 30,
		duration = 2,
		charges = 1,
		spec = { SPEC_ASSASSINATION, SPEC_SUBTLETY }
	},
})
