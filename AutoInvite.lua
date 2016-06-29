local _, FS = ...
local AutoInv = FS:RegisterModule("AutoInvite")
local Console

local connectedMates={}
local FSC_mates


local maxlevel=100
local LEGION = select(4, GetBuildInfo()) >= 70000
if LEGION then
	maxlevel=110
end

local loopTok=nil --timer token for invite loop

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
	--Scan guild if not stored
	if FSC_guildmates then
		FSC_mates=FSC_guildmates
	end
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
		GuildRoster()
		--------------------------------------------------------------------
		-- Algo
		--------------------------------------------------------------------
		--[[
		Répéter indéfiniment si groupe < 40:
			obtenir toutes les personnes connectées en guilde
			si au moins une des personnes n'est pas dans mon groupe & groupe de taille < 40 alors
				invitation de la personne
			finsi
			si le groupe est à 5 personnes et qu'il reste des personnes à inviter alors
				convertion du groupe en raido
			finsi
		fin répéter
		]]--
		--------------------------------------------------------------------
		-- loopTok=C_Timer.NewTicker(5, function() self:InviteAll() end)
		-- GuildRoster()
		-- self:GetConnected()
		-- self:Printf(#connectedMates)
		-- local raidGroup=false
		
		-- _,_,numOnlineMembers = GetNumGuildMembers()

		-- if numOnlineMembers > 5 then
			-- raidGroup=true
		-- end
		
		-- for connected=1,numOnlineMembers,1 do
			-- name, _, _, level, _, _, _, _, _, _, _,_, _, isMobile=GetGuildRosterInfo(connected);
			
			-- if not isMobile then
				-- local inMyGroup=false
				
				-- if #grouped > 0 then
					-- for i,v in grouped do 
						-- if v==name then
							-- inMyGroup=true
						-- end
					-- end
				-- end
				
				-- if not inMyGroup then
					-- InviteUnit(name)
					-- self:Printf("invite "..name)
				-- end
			-- end
		-- end
	end
end

function AutoInv:InviteRank(arg2)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		GuildRoster()
		--------------------------------------------------------------------
		-- Algo
		--------------------------------------------------------------------
		--[[
		Répéter indéfiniment si groupe < 40:
			obtenir toutes les personnes connectées en guilde
			sélectionner les personnes avec le rang arg2
			si au moins une des personnes n'est pas dans mon groupe & groupe de taille < 40 alors
				invitation de la personne
			finsi
			si le groupe est à 5 personnes et qu'il reste des personnes à inviter alors
				convertion du groupe en raid
			finsi
		fin répéter
		]]--
		--------------------------------------------------------------------
	end
end

function AutoInv:InviteRangeRank(arg2,arg3)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		GuildRoster()
		--------------------------------------------------------------------
		-- Algo
		--------------------------------------------------------------------
		--[[
		Répéter indéfiniment si groupe < 40:
			obtenir toutes les personnes connectées en guilde
			sélectionner les personnes entre le rang arg2 et arg3
			si au moins une des personnes n'est pas dans mon groupe & groupe de taille < 40 alors
				invitation de la personne
			finsi
			si le groupe est à 5 personnes et qu'il reste des personnes à inviter alors
				convertion du groupe en raid
			finsi
		fin répéter
		]]--
		--------------------------------------------------------------------
	end
end

function AutoInv:InviteLevel(level)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else
		GuildRoster()
		--------------------------------------------------------------------
		-- Algo
		--------------------------------------------------------------------
		--[[
		Répéter indéfiniment si groupe < 40:
			obtenir toutes les personnes connectées en guilde
			sélectionner les personnes avec le niveau level
			si au moins une des personnes n'est pas dans mon groupe & groupe de taille < 40 alors
				invitation de la personne
			finsi
			si le groupe est à 5 personnes et qu'il reste des personnes à inviter alors
				convertion du groupe en raid
			finsi
		fin répéter
		]]--
		--------------------------------------------------------------------
	end
end

function AutoInv:InviteRangeLevel(levelStart,levelStop)
	if loopTok then
		self:Printf("Invitations already in progress, please stop them before to inviting again")
	else

		local function update()
			self:GetConnected() -- Get all ppl connected in guild

			local connectedSelected={} --Select ppl filling the criteria
			for i=1,#connectedMates,1 do
				if connectedMates[i].level >= levelStart and connectedMates[i].level <= levelStop then
					connectedSelected[#connectedSelected+1]=connectedMates[i]
				end
			end
			self:GetPplGroup()
		end
		loopTok=C_Timer.NewTicker(5, function() update() end)
		--------------------------------------------------------------------
		-- Algo
		--------------------------------------------------------------------
		--[[
		Répéter indéfiniment si groupe < 40:
			obtenir toutes les personnes connectées en guilde
			sélectionner les personnes entre les niveaux levelStart et levelStop
			si au moins une des personnes n'est pas dans mon groupe & groupe de taille < 40 alors
				invitation de la personne
			finsi
			si le groupe est à 5 personnes et qu'il reste des personnes à inviter alors
				convertion du groupe en raid
			finsi
		fin répéter
		]]--
		--------------------------------------------------------------------
	end
end

-- if raidGroup and connected==5 then
	-- ConvertToRaid() -- revert: ConvertToParty()
-- end
-----------------------------------------------------------------------------------------------------------------------------
-- Private

function listPplGuild()
	GuildRoster() -- Game does it every 10 sec and raises GUILD_ROSTER_UPDATE event
	numTotalMembers,_,_ = GetNumGuildMembers();
	for member=1,numTotalMembers,1 do
		nm, rk, rankIndex, lvl, cls, zone, charnote, officerNote, online, stus, classFileName,achievementPoints, achievementRank, isMobile=GetGuildRosterInfo(member);
		FSC_mates[member]={["name"]=nm,
							["rank"]=rk,
							["rankIdx"]=rankIndex,
							["level"]=lvl,
							["class"]=cls,
							["note"]=charnote,
							["offinote"]=officerNote,
							["status"]=stus}
	end
	FSC_guildmates=FSC_mates
	print("Guild scan performed")
end

function AutoInv:GetConnected()
	GuildRoster()
	_,_,numOnlineMembers = GetNumGuildMembers();
	connectedMates={}
	for connected=1,numOnlineMembers,1 do
		name, rank, rankIndex, level, class, _, note, officernote, _, status, classFileName,_, _, isMobile=GetGuildRosterInfo(connected);
		connectedMates[#connectedMates+1]={["name"]=name,["rank"]=rank,["rankIndex"]=rankIndex,["level"]=level,["isMobile"]=isMobile}
	end
end

function AutoInv:GetPplGroup()
	local grouped={}
	for i=1,GetNumGroupMembers(),1 do
		name=select(1,GetRaidRosterInfo(i))
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
			end
			if arg2 and arg3 then
				self:InviteRangeLevel(tonumber(arg2),tonumber(arg3))
			end
		elseif arg1 == "scan" then
			listPplGuild()
		end
	else
		self:InviteAll()
	end
end