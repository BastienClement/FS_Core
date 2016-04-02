local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

Cooldowns:RegisterSpells({
	--
	-- Racials
	--
	[28730] = { -- Arcane Torrent
		cooldown = 90,
		duration = 3,
		race = "BloodElf",
		alias = { 50613, 202719, 80483, 129597, 155145, 25046, 69179 }
	},
	[33697] = { -- Blood Fury
		cooldown = 120,
		duration = 15,
		race = "Orc",
		alias = { 33702, 20572 },
		disabled = true
	},
	[20577] = { -- Cannibalize
		cooldown = 120,
		duration = 10,
		race = "Undead",
		disabled = true
	},
	[68992] = { -- Darkflight
		cooldown = 120,
		duration = 10,
		race = "Worgen"
	},
	[20589] = { -- Escape Artist
		cooldown = 60,
		race = "Gnome"
	},
	[59752] = { -- Every Man for Himself
		cooldown = 120,
		race = "Human"
		-- TODO: handle PVP trinket?
	},
	[59542] = { -- Gift of the Naaru
		cooldown = 180,
		duration = 5,
		race = "Draenei",
		alias = { 59545, 59543, 59548, 121093, 59544, 59547, 28880 }
	},
	[107079] = { -- Quaking Palm
		cooldown = 120,
		duration = 4,
		race = "Pandaren"
	},
	[69041] = { -- Rocket Barrage
		cooldown = 90,
		race = "Goblin",
		disabled = true
	},
	[69070] = { -- Rocket Jump
		cooldown = 90,
		race = "Goblin",
		disabled = true
	},
	[58984] = { -- Shadowmeld
		cooldown = 120,
		race = "NightElf",
		disabled = true
	},
	[20594] = { -- Stoneform
		cooldown = 120,
		duration = 8,
		race = "Dwarf"
	},
	[20549] = { -- War Stomp
		cooldown = 90,
		duration = 2,
		race = "Tauren"
	},
	[7744] = { -- Will of the Forsaken
		cooldown = 120,
		race = "Undead"
		-- TODO: handle PVP trinket?
	},
})
