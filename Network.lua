local _, FS = ...
local Network = FS:RegisterModule("Network")

LibStub("AceComm-3.0"):Embed(Network)
LibStub("AceSerializer-3.0"):Embed(Network)

local EMPTY_TABLE = {}

-- Register the addon messaging channel
function Network:OnInitialize()
	self:RegisterComm("FS")
	self:RegisterComm("FSCTRL")
	self:RegisterComm("FSCTRL")
	self.versions = {}
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
function Network:RequestVersions()
	self:SendCtrl("version_query", nil, "GUILD")
	self:SendCtrl("version_query", nil, "RAID")
end
