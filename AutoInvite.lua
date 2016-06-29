local _, FS = ...
local AutoInv = FS:RegisterModule("AutoInvite")
local Console

local connectedMates={}
local FSC_mates,playerName,homeRealm,playerFullName

local raidSizeMax=40
local loopTok --timer token for invite loop

local autoinvite_default = {
	profile = {
		
	}
}

local autoinvite_config = {
	title = {
		type = "description",
		name = "|cff64b4ffAuto Invite",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Groups into your group guildmates as soon as they connect.\n",
		fontSize = "medium",
		order = 1
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	cmds = FS.Config:MakeDoc("Available chat commands", 2000, {
		{"|cffabd473inv|r", "Enable auto invite for all guild members"},
		{"|cffabd473inv scan|r", "Scan and store all guild members"},
		{"|cffabd473inv stop|r", "Disable auto invite"},
		{"|cffabd473inv rank <rank>|r", "Enable auto invite for only guild members of rank <rank>"},
		{"|cffabd473inv rank <x> <y>|r", "Enable auto invite for guild members of rank beween x and y (included)"},
		{"|cffabd473inv level <x>|r", "Enable auto invite for guild members with level x"},
		{"|cffabd473inv level <x> <y>|r", "Enable auto invite for guild members beween level x and y"},
	}, "/fs ")
}

function AutoInv:OnInitialize()
	Console = FS:GetModule("Console")
	Console:RegisterCommand("inv", self)
	
	FS.Config:Register("Auto invite", autoinvite_config)

	self.db = FS.db:RegisterNamespace("Inv", autoinvite_default)
	self.settings = self.db.profile
end

function AutoInv:OnEnable()
	homeRealm = GetRealmName()
	playerName = UnitName("player")
	playerFullName=playerName.."-"..homeRealm
end

-----------------------------------------------------------------------------------------------------------------------
-- Public API

function AutoInv:CancelInvites()
	if loopTok then
		loopTok:Cancel()
		loopTok=nil --to be sure
		self:Printf("Invitations stopped")
	end
end


function AutoInv:InviteAll()
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		self:Printf("Inviting all connected members")
		local function update()
			local connectedMates=self:GetConnected() -- Get all ppl connected in guild

			local grouped=self:GetPplGroup()
			if #grouped < raidSizeMax then
				for i=1,#connectedMates,1 do
					local invitation=true
					for j=1,#grouped,1 do
						if connectedMates[i].name == grouped[j] then
							invitation=false
							break
						end
					end
					--Convert to raid if party full and invites pending
					if not IsInRaid() and #grouped==5 and invitation then
						ConvertToRaid()
					end

					if invitation and connectedMates[i].name~=playerFullName then
						InviteUnit(connectedMates[i].name)
					end
				end
			end
		end
		loopTok=C_Timer.NewTicker(5, function() update() end)
	end
end

function AutoInv:InviteRank(arg2)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		self:Printf("Inviting members with rank %s",arg2)
		local rank=tonumber(arg2)

		if rank >= GuildControlGetNumRanks()then
			self:Printf("Rank %d does not exists. Not inviting.",rank)
			return
		end

		local function update()
			local connectedMates=self:GetConnected() -- Get all ppl connected in guild

			local connectedSelected={} --Select ppl filling the criteria
			for i=1,#connectedMates,1 do
				if connectedMates[i].rankIndex == rank and not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			end

			local grouped=self:GetPplGroup()
			if #grouped < raidSizeMax then
				for i=1,#connectedSelected,1 do
					local invitation=true
					for j=1,#grouped,1 do
						if connectedSelected[i].name == grouped[j] then
							invitation=false
							break
						end
					end
					--Convert to raid if party full and invites pending
					if not IsInRaid() and #grouped==5 and invitation then
						ConvertToRaid()
					end

					if invitation and connectedSelected[i].name~=playerFullName then
						self:Printf("Inviting "..connectedSelected[i].name)
						InviteUnit(connectedSelected[i].name)
					end
				end
			end
		end
		loopTok=C_Timer.NewTicker(5, function() update() end)
	end
end

function AutoInv:InviteRangeRank(arg2,arg3)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		local rk1=tonumber(arg2)
		local rk2=tonumber(arg3)

		if rk1>rk2 then
			local tmp=rk1
			rk1=rk2
			rk2=tmp
		end

		self:Printf("Inviting members between rank %s and %s",rk1,rk2)

		if rk2 >= GuildControlGetNumRanks()then
			self:Printf("Rank %d does not exists. Not inviting.",rk2)
			return
		end

		local function update()
			local connectedMates=self:GetConnected() -- Get all ppl connected in guild

			local connectedSelected={} --Select ppl filling the criteria
			for i=1,#connectedMates,1 do
				if connectedMates[i].rankIndex>=tonumber(rk1)and connectedMates[i].rankIndex<=tonumber(rk2) and not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			end

			local grouped=self:GetPplGroup()
			if #grouped < raidSizeMax then
				for i=1,#connectedSelected,1 do
					local invitation=true
					for j=1,#grouped,1 do
						if connectedSelected[i].name == grouped[j] then
							invitation=false
							break
						end
					end
					--Convert to raid if party full and invites pending
					if not IsInRaid() and #grouped==5 and invitation then
						ConvertToRaid()
					end

					if invitation and connectedSelected[i].name~=playerFullName then
						self:Printf("Inviting "..connectedSelected[i].name)
						InviteUnit(connectedSelected[i].name)
					end
				end
			end
		end
		loopTok=C_Timer.NewTicker(5, function() update() end)
	end
end

function AutoInv:InviteLevel(level)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		local maxlevel=100
		local LEGION = select(4, GetBuildInfo()) >= 70000
		if LEGION then
			maxlevel=110
		end
		if not level then
			level=maxlevel
		end

		self:Printf("Inviting members at level %d",level)

		local function update()
			local connectedMates=self:GetConnected() -- Get all ppl connected in guild

			local connectedSelected={} --Select ppl filling the criteria
			for i=1,#connectedMates,1 do
				if connectedMates[i].level==tonumber(level) and not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			end

			local grouped=self:GetPplGroup()
			if #grouped < raidSizeMax then
				for i=1,#connectedSelected,1 do
					local invitation=true
					for j=1,#grouped,1 do
						if connectedSelected[i].name == grouped[j] then
							invitation=false
							break
						end
					end
					--Convert to raid if party full and invites pending
					if not IsInRaid() and #grouped==5 and invitation then
						ConvertToRaid()
					end

					if invitation and connectedSelected[i].name~=playerFullName then
						self:Printf("Inviting "..connectedSelected[i].name)
						InviteUnit(connectedSelected[i].name)
					end
				end
			end
		end
		loopTok=C_Timer.NewTicker(5, function() update() end)
	end
end

function AutoInv:InviteRangeLevel(levelStart,levelStop)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		if tonumber(levelStart) > tonumber(levelStop)then
			local tmp=tonumber(levelStart)
			levelStart=levelStop
			levelStop=tmp
		end

		self:Printf("Inviting members beteween level %d and %d",levelStart,levelStop)
		local function update()
			local connectedMates=self:GetConnected() -- Get all ppl connected in guild

			local connectedSelected={} --Select ppl filling the criteria
			for i=1,#connectedMates,1 do
				if connectedMates[i].level >= tonumber(levelStart) and connectedMates[i].level <= tonumber(levelStop) and not connectedMates[i].isMobile then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			end

			local grouped=self:GetPplGroup()
			if #grouped < raidSizeMax then
				for i=1,#connectedSelected,1 do
					local invitation=true
					for j=1,#grouped,1 do
						if connectedSelected[i].name == grouped[j] then
							invitation=false
							break
						end
					end
					--Convert to raid if party full and invites pending
					if not IsInRaid() and #grouped==5 and invitation then
						ConvertToRaid()
					end

					if invitation and connectedSelected[i].name~=playerFullName then
						self:Printf("Inviting "..connectedSelected[i].name)
						InviteUnit(connectedSelected[i].name)
					end
				end
			end

		end

		loopTok=C_Timer.NewTicker(5, function() update() end)
	end
end

-----------------------------------------------------------------------------------------------------------------------------
-- Private

function listPplGuild()
	GuildRoster() -- Game does it every 10 sec and raises GUILD_ROSTER_UPDATE event
	local numTotalMembers,_,_ = GetNumGuildMembers();
	for member=1,numTotalMembers,1 do
		local nm, rk, rankIndex, lvl, cls, zone, charnote, officerNote, online, stus, classFileName,achievementPoints, achievementRank, isMobile=GetGuildRosterInfo(member);
		FSC_mates[member]={["name"]=nm,
							["rank"]=rk,
							["rankIdx"]=rankIndex,
							["level"]=lvl,
							["class"]=cls,
							["note"]=charnote,
							["offinote"]=officerNote,
							["status"]=stus,
							["zone"]=zone,
							["online"]=online,
							["classFileName"]=classFileName,
							["achievementPoints"]=achievementPoints,
							["achievementRank"]=achievementRank,
							["isMobile"]=isMobile
						  }
	end
	print("Guild scan performed")
end

function AutoInv:GetConnected()
	GuildRoster()
	local _,_,numOnlineMembers = GetNumGuildMembers();
	local connectedMates={}
	for connected=1,numOnlineMembers,1 do
		local name, rank, rankIndex, level, _, _, _, _, _, _, _,_, _, isMobile=GetGuildRosterInfo(connected);
		connectedMates[#connectedMates+1]={["name"]=name,["rank"]=rank,["rankIndex"]=rankIndex,["level"]=level,["isMobile"]=isMobile }
	end
	return connectedMates
end

function AutoInv:GetPplGroup()
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

--------------------------------------------------------------------------------
-- Slash command handler

function AutoInv:OnSlash(arg1,arg2,arg3)
	if arg1 then
		if arg1 == "stop" then
			self:CancelInvites()
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