local _, FS = ...
local Network = FS:RegisterModule("Network")

local AceComm = LibStub("AceComm-3.0")
LibStub("AceSerializer-3.0"):Embed(Network)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local Compress = LibStub:GetLibrary("LibCompress")
local CompressEncode = Compress:GetAddonEncodeTable()

local EMPTY_TABLE = {}
local PLAYER_GUID

-- Lua APIs
local type, next, pairs, tostring = type, next, pairs, tostring
local strsub, strfind = string.sub, string.find
local match = string.match
local tinsert, tconcat = table.insert, table.concat

-- Multipart messages
local MSG_MULTI_FIRST = "\001"
local MSG_MULTI_NEXT  = "\002"
local MSG_MULTI_LAST  = "\003"
local MSG_ESCAPE = "\004"

-------------------------------------------------------------------------------
-- Options & configuration
-------------------------------------------------------------------------------

local network_default = {
	profile = {},
	global = {
		disabled = false,
		burst = false
	}
}

local version_gui = {
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
	enable = {
		type = "toggle",
		name = "Disable",
		order = 2,
		get = function() return Network.settings.disabled end,
		set = function(_, v)
			Network.settings.disabled = v
			Network:Print("Enabling/Disabling the network module requires a /reload to take effect.")
		end
	},
	burst = {
		type = "toggle",
		name = "Network burst",
		desc = "Increase addon message rate. May cause disconnect.",
		order = 1.5,
		get = function() return Network.settings.burst end,
		set = function(_, v)
			Network.settings.burst = v
			Network:Print("Enabling/Disabling network burst requires a /reload to take effect.")
		end
	},
}

local version_check
version_check = {
	title = {
		type = "description",
		name = "|cff64b4ffVersions check",
		fontSize = "large",
		order = 0,
	},
	desc = {
		type = "description",
		name = "Check the FS Core version of guild and group members.\n",
		fontSize = "medium",
		order = 1,
	},
	version_xspacing = {
		type = "description",
		name = "",
		order = 2,
	},
	--[[update_btn = {
		type = "execute",
		name = "Refresh",
		desc = "Refresh the version list with latest informations",
		order = 3,
		func = function()
			-- Dummy function to trigger Ace3 config dialog refresh
		end
	},]]
	request_btn = {
		type = "execute",
		name = "Request",
		desc = "Request guild and raid members to broadcast their FS Core version",
		order = 4,
		func = function()
			if Network:RequestVersions() then
				wipe(version_check.versions.args)
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

-------------------------------------------------------------------------------
-- Life-cycle
-------------------------------------------------------------------------------

-- Register the addon messaging channel
function Network:OnInitialize()
	-- Settings
	self.db = FS.db:RegisterNamespace("Network", network_default)
	self.settings = self.db.profile

	self.versions = {}
	self.keys = {}
	self.guids = {}

	FS:GetModule("Config"):Register("Network", version_gui)
	FS:GetModule("Config"):Register("Versions", version_check, 13)

	if self.settings.disabled then return end
	RegisterAddonMessagePrefix("FS")
end

-- Broadcast version on enable
function Network:OnEnable()
	PLAYER_GUID = UnitGUID("player")
	if self.settings.disabled then return end

	self:RegisterMessage("FS_MSG_$NET", "OnControlMessage")
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "BroadcastAnnounce")
	self:RegisterEvent("CHAT_MSG_ADDON")

	self:BroadcastAnnounce()

	if self.settings.burst then
		ChatThrottleLib.MAX_CPS = 2000
		ChatThrottleLib.BURST = 16000
		ChatThrottleLib.MIN_FPS = 0
	end
end

-------------------------------------------------------------------------------
-- Sending
-------------------------------------------------------------------------------

-- Send method
do
	-- Valid channels
	local broadcast_channels = {
		["BATTLEGROUND"] = true,
		["GUILD"] = true,
		["OFFICER"] = true,
		["PARTY"] = true,
		["RAID"] = true,
		["RAID_STRICT"] = true,
		["INSTANCE_CHAT"] = true
	}

	-- Send message to players
	-- Last arguments can be Priority (string), Multicast (table) or Callback (function)
	function Network:Send(label, data, channel, a, b, c)
		if self.settings.disabled then return end
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

		-- If channel is RAID in we are in LFG group, fix it
		-- Use RAID_STRICT to skip this behavior
		if channel == "RAID" and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
			channel = "INSTANCE_CHAT"
		elseif channel == "RAID_STRICT" then
			channel = "RAID"
		end

		-- Serialize and compress data
		local serialized = self:Serialize(label, data, multicast)
		serialized = Compress:CompressHuffman(serialized)
		serialized = CompressEncode:Encode(serialized)

		AceComm:SendCommMessage("FS", serialized, channel, target, prio, callback)
	end
end

-- Alias Send in the global object
function FS:Send(...)
	return Network:Send(...)
end

-------------------------------------------------------------------------------
-- Receive
-------------------------------------------------------------------------------

-- Handle reception without Ambiguate, thanks AceComm!
function Network:CHAT_MSG_ADDON(event, prefix, message, distribution, sender)
	if prefix ~= "FS" then return end
	local control, rest = match(message, "^([\001-\009])(.*)")
	if control then
		if control == MSG_MULTI_FIRST then
			Network:OnReceiveMultipartFirst(rest, distribution, sender)
		elseif control == MSG_MULTI_NEXT then
			Network:OnReceiveMultipartNext(rest, distribution, sender)
		elseif control == MSG_MULTI_LAST then
			Network:OnReceiveMultipartLast(rest, distribution, sender)
		elseif control == MSG_ESCAPE then
			Network:OnCommReceived(rest, distribution, sender)
		else
			-- unknown control character
		end
	else
		Network:OnCommReceived(message, distribution, sender)
	end
end

-- Multipart receiving
-- Taken from AceComm implementation
do
	local spool = {}
	local compost = setmetatable({}, { __mode = "k" })

	local function new()
		local t = next(compost)
		if t then
			compost[t]=nil
			for i = #t, 3, -1 do
				t[i] = nil
			end
			return t
		end
		return {}
	end

	function Network:OnReceiveMultipartFirst(message, distribution, sender)
		local key = distribution .. "\t" .. sender
		spool[key] = message
	end

	function Network:OnReceiveMultipartNext(message, distribution, sender)
		local key = distribution .. "\t" .. sender
		local olddata = spool[key]

		if not olddata then
			return
		end

		if type(olddata) ~= "table" then
			local t = new()
			t[1] = olddata
			t[2] = message
			spool[key] = t
		else
			tinsert(olddata, message)
		end
	end

	function Network:OnReceiveMultipartLast(message, distribution, sender)
		local key = distribution .. "\t" .. sender
		local olddata = spool[key]

		if not olddata then
			return
		end

		spool[key] = nil

		if type(olddata) == "table" then
			tinsert(olddata, message)
			Network:OnCommReceived(tconcat(olddata, ""), distribution, sender)
			compost[olddata] = true
		else
			Network:OnCommReceived(olddata .. message, distribution, sender)
		end
	end
end

-- Receive message from player
function Network:OnCommReceived(text, channel, source)
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

-------------------------------------------------------------------------------
-- Broadcast
-------------------------------------------------------------------------------

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
			Network:Send("$NET", msg, "GUILD", "BULK")
		end

		-- Raid or party members
		if IsInGroup() then
			Network:Send("$NET", msg, "RAID", "BULK")
		end

		-- Ourselves
		--Network:Send("$NET", msg, nil, "BULK")
	end

	function Network:BroadcastAnnounce()
		if self.settings.disabled then return end
		if delay then delay:Cancel() end
		delay = C_Timer.NewTimer(5, do_broadcast)
	end
end

-------------------------------------------------------------------------------
-- FS_MSG_$NET handling
-------------------------------------------------------------------------------

-- Handle FS_MSG_$NET (Network Control) messages
function Network:OnControlMessage(_, msg, channel, sender)
	local cmd, data = unpack(msg)
	if cmd == "ANNOUNCE" then
		self.keys[data.key] = sender
		self.guids[data.guid] = sender
		self.versions[data.key] = data.version

		-- TODO: rework
		version_check.last_updated.name = "Last updated: " .. date()
		version_check.versions.args[sender] = {
			type = "description",
			name = sender .. "  -  " .. data.version
		}

		AceConfigRegistry:NotifyChange("FS Core")
	elseif cmd == "REQ_ANNOUNCE" then
		self:BroadcastAnnounce()
	end
end

-------------------------------------------------------------------------------
-- Request version broadcast
-------------------------------------------------------------------------------

-- Request an upgrade of other players versions
do
	local request_cooldown = 0
	function Network:RequestVersions()
		if self.settings.disabled then return end

		local now = GetTime()
		if now < request_cooldown then
			self:Printf("Cannot request version broadcast right now, try again in %s seconds", math.ceil(request_cooldown - now))
			return false
		end
		request_cooldown = now + 30

		local msg = { "REQ_ANNOUNCE" }
		if IsInGuild() then self:Send("$NET", msg, "GUILD", "BULK") end
		if IsInGroup() then self:Send("$NET", msg, "RAID", "BULK") end
		return true
	end
end
