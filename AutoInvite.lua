local _, FS = ...
local AutoInvite = FS:RegisterModule("AutoInvite")

local Console

local callTimer=0
local playerName,homeRealm,playerFullName

local raidSizeMax=40
local loopTok --timer token for invite loop

local maxlevel=100
local LEGION = select(4, GetBuildInfo()) >= 70000
if LEGION then
	maxlevel=110
end

local connectedMates={}
local invited={}
------------------------------------------------------------------------------------------------------------------------
-- Config Auto Invite
------------------------------------------------------------------------------------------------------------------------
local autoinvite_default = {
	profile = {
		freq=5
	}
}

local autoinvite_config = {
	title = {
		type = "description",
		name = "|cff64b4ffAuto Invitation",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Group your guildmates as soon as they connect.\n",
		fontSize = "medium",
		order = 1
	},
	freq ={
		type = "input",
		name = "Invitation frequency",
		get = function() return AutoInvite.settings.freq end,
		set = function(_,val) if loopTok then AutoInvite:Stop() end AutoInvite.settings.freq=val end,
		desc= "Time to wait in seconds before resending invitations to not invited players. Default 5 sec",
		order = 5
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	cmds = FS.Config:MakeDoc("Available chat commands", 2000, {
		{"inv", "Enable auto invite for all guild members"},
		{"inv stop", "Disable auto invite"},
		{"inv rank <rank>", "Enable auto invite for only guild members of rank <rank>"},
		{"inv rank <x> <y>", "Enable auto invite for guild members of rank beween x and y (included)"},
		{"inv level <x>", "Enable auto invite for guild members with level x"},
		{"inv level <x> <y>", "Enable auto invite for guild members beween level x and y"},
	}, "/fs "),
	api = FS.Config:MakeDoc("Public API", 3000, {
		{":InviteAll ( )", "Looping invitations of all connected guild members"},
		{":InviteRank( guildRank )", "Looping invitations of all connected guild members having the specified rank. This rank can be the rankIndex or the rank name.\nBeware with ranks having spaces in it. The parameter is therefore \"The guild rank name\" "},
		{":InviteRangeRank( guildRank1 , guildRank2 )", "Looping invitations of all connected guild members having a rank within the ranks provided. Ranks can also be the rankIndex or the rank name."},
		{":InviteLevel( level )", "Looping invitations of all connected guild members having the specified level. Max level if no level provided."},
		{":InviteRangeLevel( levelStart , levelStop )", "Looping invitations of all connected guild members having a level between the specified levels."},
		{":Stop ( )", "Stops invitation looping."}
	}, "FS.Invite"),
}

------------------------------------------------------------------------------------------------------------------------
-- Module initialization

function AutoInvite:OnInitialize()
	Console = FS:GetModule("Console")
	Console:RegisterCommand("inv", self)

	self.db = FS.db:RegisterNamespace("AutoInvite", autoinvite_default)
	self.settings = self.db.profile
	FS.Config:Register("AutoInvite", autoinvite_config)
end

function AutoInvite:OnEnable()
	homeRealm = GetRealmName()
	homeRealm = homeRealm:gsub("%s+", "")
	playerName = UnitName("player")
	playerFullName = playerName.."-"..homeRealm
end

-----------------------------------------------------------------------------------------------------------------------------
-- Private

local function GetGuildRanks()
	GuildRoster()
	local numTotalMembers,_,_ = GetNumGuildMembers();
	local ranks={}
	for member=1,numTotalMembers,1 do
		_, rk, rankIndex, _, _, _, _, _, _, _, _,_, _, _=GetGuildRosterInfo(member);
		if not ranks[rankIndex+1] then
			ranks[rankIndex+1]=rk
		end
	end
	return ranks
end

local function GetConnected()
	GuildRoster()
	local _,_,numOnlineMembers = GetNumGuildMembers();
	local connectedMates={}
	for connected=1,numOnlineMembers,1 do
		local name, rank, rankIndex, level, _, _, _, _, _, _, _,_, _, isMobile=GetGuildRosterInfo(connected);
		connectedMates[#connectedMates+1]={["name"]=name,["rank"]=rank,["rankIndex"]=rankIndex,["level"]=level,["isMobile"]=isMobile }
	end
	return connectedMates
end

local function GetPplGroup()
	local grouped={}
	for i=1,GetNumGroupMembers(),1 do
		local name=select(1,GetRaidRosterInfo(i))

		if not name:find('%u%U*-%u%U') then
			name=name.."-"..homeRealm
		end
		grouped[#grouped+1]=name
	end
	return grouped
end

local function update(typeCriteria,arg1,arg2)
	if callTimer < 60 then
		callTimer=callTimer+AutoInvite.settings.freq
	else
		callTimer=0
		invited={}
	end

	local connectedMates=GetConnected() -- Get all ppl connected in guild
	
	local grouped=GetPplGroup()

	if connectedMates then
		local connectedSelected={} --Select ppl filling the criteria
		for i=1,#connectedMates,1 do
			if typeCriteria == "rangeLevel" then
				if connectedMates[i].level >= tonumber(arg1) and connectedMates[i].level <= tonumber(arg2) and not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			elseif typeCriteria == "level" then
				if connectedMates[i].level==tonumber(arg1) and not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			elseif typeCriteria == "rangeRank" then
				if connectedMates[i].rankIndex>=tonumber(arg1)and connectedMates[i].rankIndex<=tonumber(arg2) and not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			elseif typeCriteria == "rank" then
				if connectedMates[i].rankIndex == arg1 and not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			else
				if not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			end
		end


		if #grouped < raidSizeMax then
			for i=1,#connectedSelected,1 do

				local invitation=true
				for j=1,#grouped,1 do
					if connectedSelected[i].name == grouped[j] then
						invitation=false
						break
					end
				end

				if invitation then 
					for j=1,#invited,1 do
						if connectedSelected[i].name == invited[j] then
							invitation=false
							break
						end
					end
				end

				--Convert to raid if party full and invites pending
				if not IsInRaid() and #grouped==5 and invitation then
					ConvertToRaid()
				end

				if invitation and connectedSelected[i].name~=playerFullName then
					AutoInvite:Printf("Inviting "..connectedSelected[i].name) -- Might be unnecessary
					InviteUnit(connectedSelected[i].name)
					invited[#invited+1]=connectedSelected[i].name
				end

			end
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------
-- Public API

function AutoInvite:InviteAll()
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		self:Printf("Inviting all connected members")
		update()
		loopTok=C_Timer.NewTicker(self.settings.freq, function() update() end)
	end
end

function AutoInvite:InviteRank(guildRank)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		local rank=tonumber(guildRank)

		if not rank then
			for k,v in pairs(GetGuildRanks()) do
				if v==guildRank then
					rank=k-1
				end
			end
		end

		if not rank or rank >= GuildControlGetNumRanks()then
			self:Printf("Rank %s does not exists. Not inviting.",guildRank)
			return
		end

		self:Printf("Inviting members with rank %s",guildRank)
		update("rank",rank) 
		loopTok=C_Timer.NewTicker(self.settings.freq, function() update("rank",rank) end)
	end
end

function AutoInvite:InviteRangeRank(guildRank1,guildRank2)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		local rk1=tonumber(guildRank1)
		local rk2=tonumber(guildRank2)

		--Parameters are not numbers
		if not rk1 or not rk2 then
			for k,v in pairs(GetGuildRanks()) do
				if v==guildRank1 then
					rk1=k-1
				end
				if v==guildRank2 then
					rk2=k-1
				end
			end
		end

		if rk1 and rk2 and rk1>rk2 then
			local tmp=rk1
			rk1=rk2
			rk2=tmp
		end

		if not rk1 or not rk2 or rk2 >= GuildControlGetNumRanks()then
			self:Printf("One of the ranks does not exists. Not inviting.")
			return
		end
		self:Printf("Inviting members between rank %s and %s",guildRank1,guildRank2)
		update("rangeRank",rk1,rk2)
		loopTok=C_Timer.NewTicker(self.settings.freq, function() update("rangeRank",rk1,rk2) end)
	end
end

function AutoInvite:InviteLevel(level)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		if not tonumber(level) then
			level=maxlevel
		else
			level=tonumber(level)
		end

		self:Printf("Inviting members at level %d",level)
		update("level",level)
		loopTok=C_Timer.NewTicker(self.settings.freq, function() update("level",level) end)
	end
end

function AutoInvite:InviteRangeLevel(levelStart,levelStop)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		if tonumber(levelStart) > tonumber(levelStop)then
			local tmp=tonumber(levelStart)
			levelStart=levelStop
			levelStop=tmp
		end

		if levelStop > maxlevel then
			levelStop=maxlevel
			self:Printf("Limiting invites to max level")
		end

		self:Printf("Inviting members beteween level %d and %d",levelStart,levelStop)
		update("rangeLevel",levelStart,levelStop)
		loopTok=C_Timer.NewTicker(self.settings.freq, function() update("rangeLevel",levelStart,levelStop) end)
	end
end

function AutoInvite:Stop()
	if loopTok then
		loopTok:Cancel()
		loopTok=nil --to be sure
		callTimer=0
		invited={}
		self:Printf("Invitations stopped")
	end
end

--------------------------------------------------------------------------------
-- Slash command handler

function AutoInvite:OnSlash(arg1,arg2,arg3)
	if arg1 then
		if arg1 == "stop" then
			self:Stop()
		elseif arg1 == "rank" then
			if arg2 and not arg3 then
				self:InviteRank(arg2)
			end
			if arg2 and arg3 then
				self:InviteRangeRank(arg2,arg3)
			end
		elseif arg1 == "level" then
			if arg2 and not arg3 then
				self:InviteLevel(tonumber(arg2))
			elseif arg2 and arg3 then
				self:InviteRangeLevel(tonumber(arg2),tonumber(arg3))
			else
				self:InviteLevel()
			end
		end
	else
		self:InviteAll()
	end
end