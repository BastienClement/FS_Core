local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

Cooldowns:RegisterSpells({
	[155145] = { -- Arcane Torrent
		cooldown = 90,
		duration = 3,
		race = "BloodElf",
	},
})
