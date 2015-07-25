local _, FS = ...
local Network = FS:RegisterModule("Network")

LibStub("AceComm-3.0"):Embed(Network)
LibStub("AceSerializer-3.0"):Embed(Network)

local EMPTY_TABLE = {}

-- Register the addon messaging channel
function Network:OnInitialize()
	self:RegisterComm("FS")
end

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
	end
end

-- Alias Send in the global object
function FS:Send(...)
	return Network:Send(...)
end
