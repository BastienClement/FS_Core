local _, FS = ...
local Network = FS:RegisterModule("Network")

LibStub("AceComm-3.0"):Embed(Network)
LibStub("AceSerializer-3.0"):Embed(Network)

local Compress = LibStub:GetLibrary("LibCompress")
local CompressEncode = Compress:GetAddonEncodeTable()

local EMPTY_TABLE = {}
local PLAYER_GUID

local network_default = {
	profile = {},
	global = {
		burst4 = false
	}
}

-- GUI for versions informations
local version_gui
version_gui = {
	title = {
		type = "description",
		name = "|cff64b4ffNetwork",
		fontSize = "large",
		order = 0,
	},
	desc = {
		type = "description",
		name = "Provides identification, rich-values exchange and multicast transmission over whisper, raid and guild channel.\n",
		fontSize = "medium",
		order = 1,
	},
	burst = {
		type = "toggle",
		name = "Enable network burst",
		desc = "Increase addon message rate. May cause disconnect.",
		order = 1.5,
		get = function() return Network.settings.burst end,
		set = function(_, v)
			Network.settings.burst = v
			Network:Print("Enabling/Disabling network burst requires a /reload to take effect.")
		end
	},
	version_infos = {
		type = "header",
		name = "Version check",
		order = 1.8,
	},
	version_xspacing = {
		type = "description",
		name = "",
		order = 2,
	},
	update_btn = {
		type = "execute",
		name = "Refresh",
		desc = "Refresh the version list with latest informations",
		order = 3,
		func = function()
			-- Dummy function to trigger Ace3 config dialog refresh
		end
	},
	request_btn = {
		type = "execute",
		name = "Request",
		desc = "Request guild and raid members to broadcast their FS Core version",
		order = 4,
		func = function()
			if Network:RequestVersions() then
				wipe(version_gui.versions.args)
			end
		end
	},
	last_updated = {
		type = "description",
		name = "Last updated: never",
		order = 5
	},
	padding_1 = {
		type = "description",
		name = "",
		order = 6
	},
	versions = {
		type = "group",
		inline = true,
		name = "Versions",
		order = 7,
		args = {}
	}
}

-- Register the addon messaging channel
function Network:OnInitialize()
	-- Settings
	self.db = FS.db:RegisterNamespace("Network", network_default)
	self.settings = self.db.profile
	
	self:RegisterComm("FS")
	
	self.versions = {}
	self.keys = {}
	self.guids = {}
	
	FS:GetModule("Config"):Register("Network", version_gui)
end

-- Broadcast version on enable
function Network:OnEnable()
	PLAYER_GUID = UnitGUID("player")
	self:RegisterMessage("FS_MSG_NET", "OnControlMessage")
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "BroadcastAnnounce")
	self:BroadcastAnnounce()
	
	if self.settings.burst then
		ChatThrottleLib.MAX_CPS = 2000
		ChatThrottleLib.BURST = 16000
		ChatThrottleLib.MIN_FPS = 0
	end
end

do
	-- Valid channels
	local broadcast_channels = {
		["BATTLEGROUND"] = true,
		["GUILD"] = true,
		["OFFICER"] = true,
		["RAID"] = true,
		["INSTANCE_CHAT"] = true
	}

	-- Send message to players
	-- Last arguments can be Priority (string), Multicast (table) or Callback (function)
	function Network:Send(label, data, channel, a, b, c)
		local target
		
		-- Guess prio, multicast and callback from 3 last args
		local prio, multicast, callback
		do
			local function guess(param)
				local param_type = type(param)
				if param_type == "string" then
					prio = param
				elseif param_type == "table" then
					multicast = param
				elseif param_type == "function" then
					callback = param
				end
			end
			guess(a) guess(b) guess(c)
		end
		
		-- Multicast given and channel is nil
		if type(channel) == "table" then
			multicast = channel
			channel = nil
		end
		
		-- Fix missing channel or whisper
		if not channel then
			if IsInGroup() then
				channel = "RAID"
			elseif multicast then
				channel = "GUILD"
			else
				channel = "WHISPER"
				target = UnitName("player")
			end
		elseif not broadcast_channels[channel] then
			target = channel
			channel = "WHISPER"
		end

		-- Fix whisper to GUID
		if self.guids[target] then
			target = self.guids[target]
		end
		
		-- Serialize and compress data
		local serialized = self:Serialize(label, data, multicast)
		serialized = Compress:CompressHuffman(serialized)
		serialized = CompressEncode:Encode(serialized)

		self:SendCommMessage("FS", serialized, channel, target, prio, callback)
	end
end

-- Receive message from player
function Network:OnCommReceived(prefix, text, channel, source)
	if prefix == "FS" then
		-- Decompress
		text = CompressEncode:Decode(text)
		text = Compress:Decompress(text)
		if not text then return end
		
		-- Deserialize
		local res, label, data, multicast = self:Deserialize(text)
		if not res then return end
		
		-- Check multicast recipients
		if type(multicast) == "table" then
			local me = false
			for _, recipient in pairs(multicast) do
				if UnitIsUnit("player", recipient)
				or PLAYER_GUID == recipient then
					me = true
					break
				end
			end
			if not me then return end
		end
		
		-- Emit
		self:SendMessage("FS_MSG", label, data or EMPTY_TABLE, channel, source)
		self:SendMessage("FS_MSG_" .. label:upper(), data or EMPTY_TABLE, channel, source)
	end
end

-- Alias Send in the global object
function FS:Send(...)
	return Network:Send(...)
end

-- Broadcast FS Core ANNOUNCE message
do
	local delay
	
	local function do_broadcast()
		delay = nil
		
		local msg = {
			"ANNOUNCE",
			{
				version = FS.version,
				key = FS:PlayerKey(),
				guid = PLAYER_GUID
			}
		}
		
		-- Guild mates
		if IsInGuild() then
			Network:Send("NET", msg, "GUILD", "BULK")
		end
		
		-- Raid or party members
		if IsInGroup() then
			Network:Send("NET", msg, "RAID", "BULK")
		end
		
		-- Instance chat
		if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
			Network:Send("NET", msg, "INSTANCE_CHAT", "BULK")
		end
		
		-- Ourselves
		--Network:Send("NET", msg, nil, "BULK")
	end

	function Network:BroadcastAnnounce()
		if delay then delay:Cancel() end
		delay = C_Timer.NewTimer(5, do_broadcast)
	end
end

-- Handle FS_MSG_NET (Network Control) messages
function Network:OnControlMessage(_, msg, channel, sender)
	local cmd, data = unpack(msg)
	if cmd == "ANNOUNCE" then
		self.keys[data.key] = sender
		self.guids[data.guid] = sender
		self.versions[data.key] = data.version
		
		-- TODO: rework
		version_gui.last_updated.name = "Last updated: " .. date()
		version_gui.versions.args[sender] = {
			type = "description",
			name = sender .. "  -  " .. data.version
		}
	elseif cmd == "REQ_ANNOUNCE" then
		self:BroadcastAnnounce()
	end
end

-- Request an upgrade of other players versions
do
	local request_cooldown = 0
	function Network:RequestVersions()
		local now = GetTime()
		if now < request_cooldown then
			self:Printf("Cannot request version broadcast right now, try again in %s seconds", math.ceil(request_cooldown - now))
			return false
		end
		request_cooldown = now + 30
		
		local msg = { "REQ_ANNOUNCE" }
		if IsInGuild() then self:Send("NET", msg, "GUILD", "BULK") end
		if IsInGroup() then self:Send("NET", msg, "RAID", "BULK") end
		return true
	end
end
