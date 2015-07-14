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
function Network:Send(label, data, channel)
	local target
	if not channel then
		channel = "RAID"
	elseif not broadcast_channels[channel] then
		target = channel
		channel = "WHISPER"
	end
	self:SendCommMessage("FS", self:Serialize(label, data), channel, target)
end

-- Receive message from player
function Network:OnCommReceived(prefix, text, channel, source)
	if prefix == "FS" then
		local res, label, data = self:Deserialize(text)
		if res then
			self:SendMessage("FS_MSG", label, data or EMPTY_TABLE, channel, source)
		else
			self:SendMessage("FS_MSG_FAILED", label, channel, source)
		end
	end
end

-- Alias Send in the global object
function FS:Send(...)
	return Network:Send(...)
end
