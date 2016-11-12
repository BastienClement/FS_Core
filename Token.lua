local _, FS = ...
local Token = FS:RegisterModule("Token", "AceTimer-3.0")
local Network, Console, Roster

-- Aliases
local GetTime, GetNetStats, GetServerTime = GetTime, GetNetStats, GetServerTime
local UnitIsGroupLeader, UnitIsGroupAssistant, IsInGroup = UnitIsGroupLeader, UnitIsGroupAssistant, IsInGroup
local UnitPosition, UnitGUID, UnitName = UnitPosition, UnitGUID, UnitName
local pairs, ipairs, wipe, select, setmetatable, type = pairs, ipairs, wipe, select, setmetatable, type
local tinsert, tsort, tremove = table.insert, table.sort, table.remove
local After = C_Timer.After

-- Player's GUID
local PLAYER_GUID
local PLAYER_NAME
local PLAYER_ZONE

-- Defined tokens
local tokens = {}
local enabled = {}
local enabled_count = 0

-- Broadcast messages buffer
local broadcast_buffer = {}

-- Whisper messages buffer
local whisper_buffers = {}
local whisper_buffers_empty = true

-- Player's node ID
local K_NETSTATUS = "p"
local K_DEV = "d"
local K_LOADTIME = "t"
local K_GUID = "g"

local id = {
	[K_NETSTATUS] = true,
	[K_DEV] = FS.version == "dev",
	[K_LOADTIME] = 0,
	[K_GUID] = "?"
}

-- Debug trace
local debug = id[K_DEV]
function trace(...)
	if debug then
		print("TKN2", ...)
	end
end

-- States
local STATE_DISABLED    = 1 -- Token is disabled and completely ignored
local STATE_UNAVAILABLE = 2 -- Same as disabled, but because we don't have promote, automatically transition to INIT if we are promoted
local STATE_INIT        = 3 -- Init phase, sending search message and attempting to prevent causing a new election
local STATE_CLAIMING    = 4 -- Claiming the token, starting an election
local STATE_CLAIMED     = 5 -- Someone higher priority claimed the token
local STATE_ACQUIRED    = 6 -- Election is done, someone broadcasted acquire message
local STATE_DISPOSED    = 7 -- Token is disposed and should never be used again

-- Messages types
local MSG_PACKED    = "P"
local MSG_QUERY     = "Q"
local MSG_OWNER     = "O"
local MSG_CLAIM     = "C"
local MSG_ACQUIRE   = "A"
local MSG_RELEASE   = "R"
local MSG_HEARTBEAT = "H"
local MSG_SENDERID  = "I"

-- Colored states names
local state_name = {
	[STATE_DISABLED]    = "|cffc41f3bDISABLED|r",
	[STATE_UNAVAILABLE] = "|cffff7d0aUNAVAILABLE|r",
	[STATE_INIT]        = "|cfffff569INIT|r",
	[STATE_CLAIMING]    = "|cff69ccf0CLAIMING|r",
	[STATE_CLAIMED]     = "|cff69ccf0CLAIMED|r",
	[STATE_ACQUIRED]    = "|cffabd473ACQUIRED|r",
	[STATE_DISPOSED]    = "|cffc41f3bDISPOSED|r"
}

-- Track solo status
local is_solo = true

local acquirable_throttled = false

--------------------------------------------------------------------------------

local function compareNumber(a, b, key)
	a, b = a[key], b[key]
	if a == b then
		return false
	else
		-- Lower is better
		return (a < b) and 1 or -1
	end
end

local function compareBoolean(a, b, key)
	a, b = a[key], b[key]
	if a == b then
		return false
	else
		-- True is better than False
		return a and 1 or -1
	end
end

-- Compare players IDs to chose the most rightful one
local function compare(a, b)
	if not a then return -1 end
	if not b then return 1 end
	return
		compareBoolean(a, b, K_NETSTATUS) or -- Good network health wins
		compareBoolean(a, b, K_DEV) or -- Dev wins
		compareNumber(a, b, K_LOADTIME) or -- Lowest load time wins
		compareNumber(a, b, K_GUID) or -- Lowest GUID wins
		0
end

--------------------------------------------------------------------------------

local token_config = {
	title = {
		type = "description",
		name = "|cff64b4ffService Token",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Distributed service coordinator election service.\n",
		fontSize = "medium",
		order = 1
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	cmds = FS.Config:MakeDoc("Available chat commands", 1900, {
		{"token", "List active tokens state and owner."},
	}, "/fs "),
	docs = FS.Config:MakeDoc("Public API", 2000, {
		{":Create ( name , default ) -> token", "Creates a new service token with the given name. At any given time, only one player in the group can hold a token with a given name."},
	}, "FS.Token"),
	token = FS.Config:MakeDoc("Token API", 3000, {
		{":Enable ( )", "Enable this token and participate in the holder election process."},
		{":Disable ( )", "Disable this token. The player will no longer participate in the holder election process and will release the token if currently owning the token."},
		{":IsMine ( ) -> boolean", "Returns true if the player is currently the token holder."},
		{":Owner ( ) -> guid , name", "Returns the GUID and name of the current token holder."},
	}, "token"),
	events = FS.Config:MakeDoc("Emitted events", 4000, {
		{"_ACQUIRED ( name , token )", "Emitted when a new holder is elected for the token."},
		{"_WON ( name , token )", "Emitted when the player is now the holder of a token."},
		{"_LOST ( name , token )", "Emitted when the player is no longer the holder of a token."},
	}, "FS_TOKEN")
}

--------------------------------------------------------------------------------

function Token:OnInitialize()
	Network = FS.Network
	Roster = FS.Roster
	Console = FS.Console

	Console:RegisterCommand("token", self)
	FS.Config:Register("Service token", token_config)
end

function Token:OnEnable()
	-- Fetch player's GUID
	PLAYER_GUID = UnitGUID("player"):sub(8)
	PLAYER_NAME = UnitName("player")

	-- Update ID table
	id[K_GUID] = PLAYER_GUID
	id[K_LOADTIME] = GetServerTime()

	-- Bind token network messages
	self:RegisterMessage("FS_MSG_TKN2")

	-- Check group composition change
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "UpdateAcquirable")

	-- Check entering / exiting instances
	self:RegisterEvent("ZONE_CHANGED", "UpdateAcquirable")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateAcquirable")

	-- Force an initial check
	self:UpdateNetworkHealth()
	self:UpdateAcquirable()
end

function Token:EnableToken(token)
	if enabled[token.name] then return end

	enabled[token.name] = token
	enabled_count = enabled_count + 1

	if enabled_count == 1 then
		self:ScheduleRepeatingTimer("UpdateNetworkHealth", 10)
		self:ScheduleRepeatingTimer("BroadcastHeartbeat", 2)
		self:ScheduleRepeatingTimer("CheckTimeouts", 2)
	end
end

function Token:DisableToken(token)
	if not enabled[token.name] then return end

	enabled[token.name] = nil
	enabled_count = enabled_count - 1

	if enabled_count == 0 then
		self:CancelAllTimers()
		self:FlushBuffers()
	end
end

--------------------------------------------------------------------------------

-- Broadcast a message to every players in the group
function Token:Broadcast(msg, callback)
	if type(callback) == "function" then
		msg._callback = callback
	end
	tinsert(broadcast_buffer, msg)
	self:ScheduleFlushBuffers()
	return msg
end

-- Cancel a message sent by Token:Broadcast if this is still possible
-- Must be called before Token:FlushBuffers is called.
function Token:CancelBroadcast(msg)
	if #broadcast_buffer < 1 then return end
	for i, m in ipairs(broadcast_buffer) do
		if m == msg then
			tremove(broadcast_buffer, i)
			return
		end
	end
end

-- Send a message to a specific player
function Token:Whisper(msg, target, callback)
	local target_buffer = whisper_buffers[target]
	if not target_buffer then
		target_buffer = {}
		whisper_buffers[target] = target_buffer
		whisper_buffers_empty = false
	end
	if type(callback) == "function" then
		msg._callback = callback
	end
	tinsert(target_buffer, msg)
	self:ScheduleFlushBuffers()
	return msg
end

do
	-- Is an output buffer flush scheduled?
	local flush_scheduled = false

	-- Execute every registered callbacks
	local function execute_callback(msgs)
		for _, msg in ipairs(msgs) do
			if msg._callback then
				msg._callback()
				msg._callback = nil
			end
		end
	end

	-- Flush output messages buffers
	-- Buffers are used to group messages related to independant tokens in the same common message
	function Token:FlushBuffers()
		if #broadcast_buffer > 0 then
			execute_callback(broadcast_buffer)
			if IsInGroup() then
				Network:Send("TKN2", {
					[MSG_PACKED] = broadcast_buffer,
					[MSG_SENDERID] = id
				}, "RAID")
			end
			wipe(broadcast_buffer)
		end

		if not whisper_buffers_empty then
			for target, buffer in pairs(whisper_buffers) do
				execute_callback(buffer)
				Network:Send("TKN2", {
					[MSG_PACKED] = buffer,
					[MSG_SENDERID] = id
				}, target)
			end
			wipe(whisper_buffers)
			whisper_buffers_empty = true
		end
	end

	function Token:ScheduleFlushBuffers()
		if flush_scheduled then return end
		flush_scheduled = true
		After(0.5, function()
			flush_scheduled = false
			Token:FlushBuffers()
		end)
	end
end

-- Broadcast player heartbeats
function Token:BroadcastHeartbeat()
	for name, token in pairs(enabled) do
		if token:IsMine() then
			self:Broadcast({ [MSG_HEARTBEAT] = true })
			return
		end
	end
end

-- Check token owner liveness
function Token:CheckTimeouts()
	-- Do not check timeouts if we have more than 500 ms latency
	if not id[K_NETSTATUS] then return end

	local now = GetTime()
	for name, token in pairs(enabled) do
		if (token.state == STATE_ACQUIRED and not token:IsMine()) or
				token.state == STATE_CLAIMED then
			-- Token stuck in CLAIMED or no heartbeats from owner
			if now - token.ping > 5 then
				trace("#", token.name, "timed out", state_name[token.state])
				token:Claim()
			end
		end
	end
end

function Token:UpdateAcquirable()
	if not acquirable_throttled then
		self:ScheduleTimer("DoUpdateAcquirable", 1)
		acquirable_throttled = true
	end
end

function Token:DoUpdateAcquirable()
	acquirable_throttled = false
	PLAYER_ZONE = select(4, UnitPosition("player"))

	local in_group = IsInGroup()
	local entering_group = is_solo and in_group
	is_solo = not in_group

	for name, token in pairs(tokens) do
		local acquirable = token:IsAcquirable()
		if token:IsEnabled() and not acquirable then
			trace("#", token.name, "is no longer acquirable")
			token:Disable(true, entering_group)
		elseif token.state == STATE_UNAVAILABLE and acquirable then
			trace("#", token.name, "is now acquirable")
			token:Enable()
		end
	end
end

function Token:UpdateNetworkHealth()
	local _, _, latencyHome, latencyWorld = GetNetStats()
	id[K_NETSTATUS] = latencyHome < 500 and latencyWorld < 500
end

--------------------------------------------------------------------------------

-- Received a token-related network message
function Token:FS_MSG_TKN2(_, data, channel, sender)
	local senderid = data[MSG_SENDERID]
	if not senderid then return end

	-- Packed messages
	if data[MSG_PACKED] then
		-- Ignore our own messages
		if senderid[K_GUID] == PLAYER_GUID then return end

		-- Iterate for each message
		for _, item in ipairs(data[MSG_PACKED]) do
			item[MSG_SENDERID] = senderid
			self:FS_MSG_TKN2(nil, item, channel, sender)
		end

	-- Search request on token init
	elseif data[MSG_QUERY] then
		local token = enabled[data[MSG_QUERY]]
		if token then
			trace("<", "QUERY", data[MSG_QUERY], sender)
			if token:IsMine() then
				trace(">", "OWNER", token.name, sender)
				self:Whisper({ [MSG_OWNER] = token.name }, sender)
			end
		end

	-- Current token owner response
	elseif data[MSG_OWNER] then
		local token = enabled[data[MSG_OWNER]]
		if token then
			trace("<", "OWNER", data[MSG_OWNER], sender)
			if token.state == STATE_INIT then
				if id[K_DEV] and compare(id, senderid) > 0 then
					-- Only devs bullies when system is stable
					token:Claim()
				else
					-- Righteous answer to MSG_QUERY
					token:SetOwner(senderid, sender)
				end
			end
		end

	-- Token claim
	elseif data[MSG_CLAIM] then
		local token = enabled[data[MSG_CLAIM]]
		if token then
			trace("<", "CLAIM", data[MSG_CLAIM], sender)
			local now = GetTime()
			-- Claimer ID is lower priority than me, bully
			if compare(id, senderid) > 0 then
				if now - token.ping > 2 then
					token:Claim()
				end
			elseif (GetTime() - token.ping > 3) or
					(compare(senderid, token.owner) > 0) then
				if token.state == STATE_CLAIMING then
					token:CancelClaim()
				end
				token.state = STATE_CLAIMED
				token.owner = senderid
				token.owner_name = sender
				token.ping = GetTime()
			end
		end

	-- Token acquire announce
	elseif data[MSG_ACQUIRE] then
		local token = enabled[data[MSG_ACQUIRE]]
		if token then
			trace("<", "ACQUIRE", data[MSG_ACQUIRE], sender)
			-- Not the rightful owner
			if compare(id, senderid) > 0 then
				token:Claim()
			else
				token:SetOwner(senderid, sender)
			end
		end

	-- Token released
	elseif data[MSG_RELEASE] then
		local token = enabled[data[MSG_RELEASE]]
		if token then
			trace("<", "RELEASE", data[MSG_RELEASE], sender)
			token:Claim()
		end

	-- Player heartbeat
	elseif data[MSG_HEARTBEAT] then
		local now = GetTime()
		for name, token in pairs(enabled) do
			-- Uptime ping for each token belonging to the player
			if token.state == STATE_ACQUIRED and compare(token.owner, senderid) == 0 then
				token.ping = now
			end
		end

	end
end

--------------------------------------------------------------------------------

local TokenObj = {}
TokenObj.__index = TokenObj

-- Creates a new Token object
function TokenObj:New(name)
	return setmetatable({
		name = name,
		promote = false,
		zone = false,
		state = STATE_DISABLED,
		owner = nil,
		owner_name = nil,
		last_owner = nil,
		ping = 0
	}, TokenObj)
end

function TokenObj:RequirePromote(flag)
	self.promote = flag
	return self
end

function TokenObj:RequireZone(zoneid)
	self.zone = zoneid
	return self
end

-- Enable the token, attempting to claim it
function TokenObj:Enable()
	if self.state > STATE_UNAVAILABLE then
		-- Token is already enabled
	elseif not self:IsAcquirable() then
		-- Token is not acquireable, wait
		self.state = STATE_UNAVAILABLE
	else
		-- Enable the token
		self.state = STATE_INIT
		Token:EnableToken(self)

		trace("#", self.name, "is now enabled")
		trace(">", "QUERY", self.name)

		-- Search the current owner
		Token:Broadcast({ [MSG_QUERY] = self.name }, function()
			-- If no answers after 3 sec, claim it
			After(3, function()
				if self.state == STATE_INIT then
					trace("#", self.name, "no responses to QUERY")
					self:Claim()
				end
			end)
		end)
	end
end

-- Disable the token, releasing it if we own it
function TokenObj:Disable(unavailable, no_release)
	if self.state ~= STATE_DISABLED and self.state ~= STATE_DISPOSED then
		-- Release the token if we own it
		if self:IsMine() and not no_release then
			trace(">", "RELEASE", self.name)
			Token:Broadcast({ [MSG_RELEASE] = self.name })
		end

		-- Disable the token if previously enabled
		if self.state > STATE_UNAVAILABLE then
			Token:DisableToken(self)
		end

		if self:IsMine() then
			Token:SendMessage("FS_TOKEN_LOST", self.name, self)
		end

		-- Update state
		self.state = unavailable and STATE_UNAVAILABLE or STATE_DISABLED

		-- Erase owner information
		self.owner = nil
		self.owner_name = nil
		self.last_owner = nil

		trace("#", self.name, "is now disabled")
	end
end

function TokenObj:IsEnabled()
	return self.state > STATE_UNAVAILABLE and self.state ~= STATE_DISPOSED
end

function TokenObj:SetEnabled(enabled)
	if enabled and self.state == STATE_DISABLED then
		self:Enable()
	elseif not enabled and self.state > STATE_DISABLED and self.state ~= STATE_DISPOSED then
		self:Disable()
	end
end

-- Check if the token is acquirable (require raid promote and we have it)
function TokenObj:IsAcquirable()
	local solo = not IsInGroup()
	local promoted = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
	return (solo or (not self.promote or promoted)) and (not self.zone or self.zone == PLAYER_ZONE)
end

-- Attempts to claim and acquire the token
function TokenObj:Claim()
	-- Token is not claimable
	if self.state < STATE_INIT or self.state > STATE_ACQUIRED then
		return
	end

	-- Claiming the token
	-- When claiming as bullying, do not change the state flag
	-- This ensure that the token is not lost until after the election is completed
	if not self:IsMine()  then
		self.state = STATE_CLAIMING
		self.owner = id
		self.owner_name = PLAYER_NAME
		self.ping = GetTime()
		trace("#", self.name, "claim started")
	else
		trace("#", self.name, "bullying")
	end

	trace(">", "CLAIM", self.name)
	self.claim_msg = Token:Broadcast({ [MSG_CLAIM] = self.name }, function()
		self.claim_msg = nil
		-- If we get no answers after 3 sec, consider we have acquired the token
		After(3, function()
			if (self.state == STATE_CLAIMING or self.state == STATE_ACQUIRED) and
					self.owner[K_GUID] == PLAYER_GUID then
				trace("#", self.name, "no responses to CLAIM")
				self:SetOwner(id, PLAYER_NAME)
				Token:Broadcast({ [MSG_ACQUIRE] = self.name })
				trace(">", "ACQUIRE", self.name)
			end
		end)
	end)
end

-- Cancels the claim if we received another better one before effectively sending our claim
function TokenObj:CancelClaim()
	local claim = self.claim_msg
	if claim then
		Token:CancelBroadcast(claim)
		self.claim_msg = nil
		trace("#", self.name, "claim canceled")
	end
end

-- Sets the token owner and state to ACQUIRED
function TokenObj:SetOwner(ownerid, name)
	-- Checks if we previsouly were the token owner
	local was_mine = self.last_owner == PLAYER_GUID
	local is_mine = ownerid[K_GUID] == PLAYER_GUID

	-- Update state
	self.state = STATE_ACQUIRED
	self.owner = ownerid
	self.owner_name = name
	self.ping = GetTime()

	if ownerid[K_GUID] ~= self.last_owner then
		if was_mine then Token:SendMessage("FS_TOKEN_LOST", self.name, self) end
		Token:SendMessage("FS_TOKEN_ACQUIRED", self.name, self)
		if is_mine then Token:SendMessage("FS_TOKEN_WON", self.name, self) end
	end

	trace("#", self.name, "owner set to", name)
	self.last_owner = ownerid[K_GUID]
end

-- Returns the token owner GUID and name
function TokenObj:Owner()
	if self.state == STATE_ACQUIRED then
		return self.owner[K_GUID], self.owner_name
	else
		return nil, nil
	end
end

-- Checks if we are the current owner of the token
function TokenObj:IsMine()
	return self.state == STATE_ACQUIRED and self.owner[K_GUID] == PLAYER_GUID
end

-- Dispose of the token, never doing anything with it again
function TokenObj:Dispose(upgrade)
	self:Disable(false, upgrade)
	self.state = STATE_DISPOSED
end

--------------------------------------------------------------------------------

-- Create a new token object
function Token:Create(name, default)
	local old = tokens[name]
	if old then old:Dispose(false, true) end

	local token = TokenObj:New(name)
	tokens[name] = token

	if default ~= false then
		After(0, function()
			token:Enable()
		end)
	end

	return token
end

--------------------------------------------------------------------------------

function Token:OnSlash(arg, ...)
	local lines = {}
	for _, token in pairs(arg == "all" and tokens or enabled) do
		local owner_name = token.state >= STATE_CLAIMING and token.owner_name or ""
		local line = ("  |cffc79c6e%s  |cff999999%s  %s"):format(token.name, state_name[token.state], owner_name)
		tinsert(lines, line)
	end

	self:Printf("Listing %s |4token:tokens;", #lines)

	tsort(lines)
	for _, line in ipairs(lines) do
		print(line)
	end
end
