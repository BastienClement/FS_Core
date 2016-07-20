local _, FS = ...
local Misc = FS:RegisterModule("Miscellaneous")

local features = {}

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

local misc_defaults = {
	profile = {
		disable_talkinghead = false,
		enable_slashrl = true,
	}
}

local misc_config = {
	title = {
		type = "description",
		name = "|cff64b4ffMiscellaneous",
		fontSize = "large",
		order = 0,
	},
	desc = {
		type = "description",
		name = "Various useful options.\n",
		fontSize = "medium",
		order = 1,
	},
}

-------------------------------------------------------------------------------
-- Life-cycle
-------------------------------------------------------------------------------

function Misc:OnInitialize()
	self.db = FS.db:RegisterNamespace("Miscellaneous", misc_defaults)
	self.settings = self.db.profile
	FS.Config:Register("Miscellaneous", misc_config, 12)
end

function Misc:OnEnable()
	for name in pairs(features) do
		self:SyncFeature(name)
	end
end

do
	local order = 10
	function Misc:RegisterFeature(name, short, long, fn)
		misc_config[name] = {
			type = "toggle",
			name = short,
			descStyle = "inline",
			desc = "|cffaaaaaa" .. long,
			width = "full",
			get = function() return Misc.settings[name] end,
			set = function(_, v)
				Misc.settings[name] = v
				Misc:SyncFeature(name)
			end,
			order = order
		}
		order = order + 1
		features[name] = fn
	end
end

function Misc:SyncFeature(name)
	features[name](Misc.settings[name])
end

-------------------------------------------------------------------------------
-- Features
-------------------------------------------------------------------------------

Misc:RegisterFeature(
	"TalkingHead",
	"Disable Talking Head",
	"Disables the Talking Head feature that is used for some quest and event dialogues.",
	function(state)
		if state then
			UIParent:UnregisterEvent("TALKINGHEAD_REQUESTED")
		else
			UIParent:RegisterEvent("TALKINGHEAD_REQUESTED")
		end
	end
)

do
	local rlEnabled = false
	Misc:RegisterFeature(
		"SlashRL",
		"Enable /rl",
		"Enables the short version for reloading the interface.",
		function(state)
			if state and not rlEnabled then
				rlEnabled = true
				FS.Console:RegisterChatCommand("rl", function() ReloadUI() end)
			end
		end
	)
end
