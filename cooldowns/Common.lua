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
	[59542] = { -- Gift of the Naaru
		cooldown = 180,
		duration = 5,
		race = "Draenei",
		alias = { 59545, 59543, 59548, 121093, 59544, 59547, 28880 }
	},
	[20549] = { -- War Stomp
		cooldown = 90,
		duration = 2,
		race = "Tauren"
	},
})
