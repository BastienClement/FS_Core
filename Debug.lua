local _, FS = ...
local Debug = FS:RegisterModule("Debug")

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

local debug_defaults = {
	profile = {
		debug = false,
	}
}

local debug_config = {
	title = {
		type = "description",
		name = "|cff64b4ffDebug",
		fontSize = "large",
		order = 0,
	},
	desc = {
		type = "description",
		name = "Development and debug functionalities.\n",
		fontSize = "medium",
		order = 1,
	},
	debug = {
		type = "toggle",
		name = "Enable DEBUG logging",
		descStyle = "inline",
		width = "full",
		get = function() return Debug.settings.debug end,
		set = function(_, v) Debug.settings.debug = v end,
		order = 6
	},
	debug_desc = {
		type = "description",
		name = "|cff999999Enable logging of DEBUG-level events.\nThis may cause wasted CPU usage if you do not care about debug events.\n",
		order = 7,
		width = "full"
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000,
	},
	docs = FS.Config:MakeDoc("Public API", 2000, {
		{":Dump ( obj )", "Dumps the given object in the chat."},
	}, "FS"),
	levels = FS.Config:MakeDoc("Logging API", 3000, {
		{":Error ( label , data )", "Critical error preventing the addon from producing any results at all."},
		{":Warn ( label , data )", "Serious error that does not prevent the addon from performing its task."},
		{":Info ( label , data )", "Informational data that may be useful to a moderately advanced users."},
		{":Debug ( label , data )", "Debug data useful only for developers."},
	}, "FS"),
	events = FS.Config:MakeDoc("Emitted events", 4000, {
		{"_LOG ( level , label , data )", "Emitted when a logging function is called.\nLevel will be \"ERROR\", \"WARNING\", \"INFO\" or \"DEBUG\"."},
	}, "FS_DEBUG"),
}

-------------------------------------------------------------------------------
-- Life-cycle
-------------------------------------------------------------------------------

function Debug:OnInitialize()
	self.db = FS.db:RegisterNamespace("Debug", debug_defaults)
	self.settings = self.db.profile
	FS.Config:Register("Debug", debug_config)
end

-------------------------------------------------------------------------------
-- Utils
-------------------------------------------------------------------------------

do
	local colors = {
		["string"] = "fffff569",
		["number"] = "ffff7d0a",
		["table"] = "ffabd473",
		["function"] = "ff69ccf0",
	}

	function Debug:TypeColor(type)
		return colors[type] or "ff00ff96"
	end
end

-------------------------------------------------------------------------------
-- Dump
-------------------------------------------------------------------------------

-- Dump helper
function FS:Dump(t)
	local dump_cache = {}
	local function to_string(v)
		local tpe = type(v)
		local prefix = "|c" .. Debug:TypeColor(tpe)
		local suffix = "|r"

		if tpe == "string" then
			prefix = prefix .. "\""
			suffix = "\"" .. suffix
		end

		return prefix .. tostring(v) .. suffix
	end
	local function sub_dump(t, indent)
		local t_str = to_string(t)
		if dump_cache[t_str] then
			print(indent .. "*" .. t_str)
		else
			dump_cache[t_str] = true
			if type(t) == "table" then
				for pos, val in pairs(t) do
					if type(val) == "table" then
						print(indent .. to_string(pos) .. " => " .. to_string(val) .." {")
						sub_dump(val, indent .. (" "):rep(4))
						print(indent .. "}")
					else
						print(indent .. to_string(pos) .. " => " .. to_string(val))
					end
				end
			else
				print(indent .. t_str)
			end
		end
	end
	sub_dump(t, " ")
end

-------------------------------------------------------------------------------
-- Logging
-------------------------------------------------------------------------------

function FS:Error(label , data)
	error("NYI")
end

function FS:Warn(label , data)
	error("NYI")
end

function FS:Info(label , data)
	error("NYI")
end

function FS:Debug(label , data)
	error("NYI")
end
