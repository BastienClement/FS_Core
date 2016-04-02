local _, FS = ...
local Cooldowns = FS:GetModule("Cooldowns")

if select(4, GetBuildInfo()) < 70000 then
	return
end

local SPEC_HAVOC = 577
local SPEC_VENGEANCE = 581

Cooldowns:RegisterSpells("DEMONHUNTER", {
	[188499] = { -- Blur
		cooldown = 60,
		duration = 10,
	},
	[179057] = { -- Chaos Nova
		cooldown = 60,
		duration = 5,
	},
	[183752] = { -- Consume Magic
		cooldown = 20,
		duration = 3,
		alias = 183782 -- Wowhead ?!
	},
	[191427] = { -- Metamorphosis
		cooldown = 300,
		duration = 30,
		--tag = "AOE_STUN"  I don't think it should be tagged AOE_STUN
	},
})
