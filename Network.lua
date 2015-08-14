local _, FS = ...
local Network = FS:RegisterModule("Network")

LibStub("AceComm-3.0"):Embed(Network)
LibStub("AceSerializer-3.0"):Embed(Network)

local EMPTY_TABLE = {}

-- GUI for versions informations
local version_gui = {
	title = {
		type = "description",
		name = "|cff64b4ffVersions",
		fontSize = "large",
		order = 0,
	},
	desc = {
		type = "description",
		name = "This tab allows you to see guild and raid members version of FS Core.\n",
		fontSize = "medium",
		order = 1,
	},
	update_btn = {
		type = "execute",
		name = "Refresh",
		desc = "Refresh the version list with latest informations",
		order = 2,
		func = function()
			-- Dummy function to trigger Ace3 config dialog refresh
		end
	},
	request_btn = {
		type = "execute",
		name = "Request version broadcast",
		desc = "Request guild and raid members to broadcast their FS Core version",
		order = 3,
		func = function()
			Network:RequestVersions()
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
	self:RegisterComm("FS")
	self:RegisterComm("FSCTRL")
	self.versions = {}
	
	FS:GetModule("Config"):Register("Versions", version_gui)
end

-- Broadcast version on enable
function Network:OnEnable()
	C_Timer.After(5, function()
		self:BroadcastVersion()
	end)
end

do
	-- Valid channels
	local broadcast_channels = {
		["BATTLEGROUND"] = true,
		["GUILD"] = true,
		["OFFICER"] = true,
		["RAID"] = true
	}

	-- Send message to players
	function Network:Send(label, data, channel, multicast)
		local target
		
		-- Multicast given and channel is nil
		if type(channel) == "table" then
			multicast = channel
			channel = nil
		end
		
		if not channel then
			if IsInRaid() or IsInGroup() then
				channel = "RAID"
			else
				channel = "WHISPER"
				target = UnitName("player")
			end
		elseif not broadcast_channels[channel] then
			target = channel
			channel = "WHISPER"
		end
		
		self:SendCommMessage("FS", self:Serialize(label, data, multicast), channel, target)
	end
end

-- Receive message from player
function Network:OnCommReceived(prefix, text, channel, source)
	if prefix == "FS" then
		local res, label, data, multicast = self:Deserialize(text)
		if res then
			if type(multicast) == "table" then
				local me = false
				for _, recipient in pairs(multicast) do
					if UnitIsUnit("player", recipient) then
						me = true
						break
					end
				end
				if not me then return end
			end
			self:SendMessage("FS_MSG", label, data or EMPTY_TABLE, channel, source)
			self:SendMessage("FS_MSG_" .. label:upper(), data or EMPTY_TABLE, channel, source)
		end
	elseif prefix == "FSCTRL" then
		local action, data = text:match("([^ ]+) (.*)")
		if action == "version" then
			self.versions[source] = data
			version_gui.last_updated.name = "Last updated: " .. date()
			version_gui.versions.args[source] = {
				type = "description",
				name = source .. "  -  " .. data
			}
		elseif action == "version_query" then
			self:BroadcastVersion()
		end
	end
end

-- Alias Send in the global object
function FS:Send(...)
	return Network:Send(...)
end

-- Send control message
function Network:SendCtrl(action, data, channel, target)
	self:SendCommMessage("FSCTRL", action .. " " .. (data or ""), channel)
end

-- Broadcast FS Core version
function Network:BroadcastVersion()
	local version =  FS.version
	self:SendCtrl("version", version, "GUILD")
	self:SendCtrl("version", version, "RAID")
end

-- Request an upgrade of other players versions
do
	local request_cooldown = 0
	function Network:RequestVersions()
		local now = GetTime()
		if now < request_cooldown then
			self:Printf("Cannot request version broadcast right now, try again in %s seconds", math.ceil(request_cooldown - now))
			return
		end
		request_cooldown = now + 30
		self:SendCtrl("version_query", nil, "GUILD")
		self:SendCtrl("version_query", nil, "RAID")
	end
end
