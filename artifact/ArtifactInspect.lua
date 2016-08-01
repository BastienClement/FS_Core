local _, FS = ...
local ArtifactInspect = FS:RegisterModule("ArtifactInspect")

local Roster

--------------------------------------------------------------------------------
-- Module initialization

function ArtifactInspect:OnInitialize()
	Roster = FS:GetModule("Roster")

	self.data = nil
	self.active = 0

	self.inspectable = nil
	self.inspectableUnit = nil

	self:RegisterMessage("FS_MSG_AI_PROBE")
	self:RegisterMessage("FS_MSG_AI_PROBE_REPLY")
	self:RegisterMessage("FS_MSG_AI_REQUEST")
	self:RegisterMessage("FS_MSG_AI_DATA")

	UnitPopupButtons["ARTIFACT_INSPECT"] = { text = "Inspect Artifact", dist = 0 }

	for menu, items in pairs(UnitPopupMenus) do
		for i = 0, #items do
			if items[i] == "INSPECT" then
				table.insert(items, i + 1, "ARTIFACT_INSPECT")
				break
			end
		end
	end

	hooksecurefunc("UnitPopup_OnUpdate", function(elapsed)
		if not DropDownList1:IsShown() then return end

		local currentDropDown = UIDROPDOWNMENU_OPEN_MENU
		local unit = currentDropDown.unit
		if not unit then return end

		local available = true

		if UnitIsConnected(unit) and UnitIsFriend(unit, "player") and UnitIsPlayer(unit) then
			local unitName = GetUnitName(currentDropDown.unit, true)
			available = ArtifactInspect:IsInspectable(unitName)
		else
			available = false
		end

		-- Loop through all menus and enable/disable their buttons appropriately
		local count, tempCount
		for level, dropdownFrame in pairs(OPEN_DROPDOWNMENUS) do
			if dropdownFrame then
				count = 0
				for index, value in ipairs(UnitPopupMenus[dropdownFrame.which]) do
					if UnitPopupShown[level][index] == 1 then
						count = count + 1
						local notClickable = false

						local diff = (level > 1) and 0 or 1

						if UnitPopupButtons[value].isSubsectionTitle then
							--If the button is a title then it has a separator above it that is not in UnitPopupButtons.
							--So 1 extra is added to each count because UnitPopupButtons does not count the separators and
							--the DropDown does.
							tempCount = count + diff
							count = count + 1
						else
							tempCount = count + diff
						end

						if value == "ARTIFACT_INSPECT" then
							if available then
								UIDropDownMenu_EnableButton(level, tempCount)
							else
								if notClickable == 1 then
									UIDropDownMenu_SetButtonNotClickable(level, tempCount)
								else
									UIDropDownMenu_SetButtonClickable(level, tempCount)
								end
								UIDropDownMenu_DisableButton(level, tempCount)
							end
						end
					end
				end
			end
		end
	end)

	hooksecurefunc("UnitPopup_OnClick", function(self)
		local dropdownFrame = UIDROPDOWNMENU_INIT_MENU
		local button = self.value
		local unit = dropdownFrame.unit
		if button == "ARTIFACT_INSPECT" then
			local unitName = GetUnitName(unit, true)
			ArtifactInspect:Inspect(unitName)
		end
	end)
end

function ArtifactInspect:OnEnable()
end

--------------------------------------------------------------------------------
-- API

function ArtifactInspect:Probe(target)
	FS:Send("AI_PROBE", nil, target)
end

function ArtifactInspect:Inspect(target)
	FS:Send("AI_REQUEST", nil, target)
end

function ArtifactInspect:IsInspectable(target)
	if self.inspectableUnit ~= target then
		self.inspectable = false
		self.inspectableUnit = target
		self:Probe(target)
	end
	return self.inspectable
end

--------------------------------------------------------------------------------
-- Internal API

function ArtifactInspect:HasData()
	return not not self.data
end

function ArtifactInspect:GetActiveArtifact()
	return self.data[self.active]
end

function ArtifactInspect:GetArtifactMeta()
	return self:GetActiveArtifact().meta
end

function ArtifactInspect:GetArtifactInfo()
	local m = self:GetArtifactMeta()
	return m.itemID, m.altItemID, m.artifactAppearanceID, m.appearanceModID, m.itemAppearanceID, m.altItemAppearanceID, m.altOnTop
end

function ArtifactInspect:GetAppearanceInfo()
	local m = self:GetArtifactMeta()
	return m.uiCameraID, m.altHandUICameraID, m.modelAlpha, m.modelDesaturation, m.suppressGlobalAnim
end

function ArtifactInspect:GetArtifactArtInfo()
	local m = self:GetArtifactMeta()
	return m.textureKit, m.titleName, m.titleR, m.titleG, m.titleB, m.barConnectedR, m.barConnectedG, m.barConnectedB, m.barDisconnectedR, m.barDisconnectedG, m.barDisconnectedB
end

function ArtifactInspect:GetTotalPurchasedRanks()
	return self:GetActiveArtifact().numRanksPurchased
end

function ArtifactInspect:GetArtifactKnowledgeLevel()
	return self.data.knowledgeLevel
end

function ArtifactInspect:GetArtifactKnowledgeMultiplier()
	return self.data.knowledgeMultiplier
end

function ArtifactInspect:GetPointsRemaining()
	return self:GetActiveArtifact().unspentPower
end

function ArtifactInspect:GetNumRelicSlots()
	return #self:GetActiveArtifact().relics
end

function ArtifactInspect:GetRelicSlotType(i)
	return self:GetActiveArtifact().relics[i].type
end

function ArtifactInspect:GetRelicInfo(i)
	local r = self:GetActiveArtifact().relics[i]
	return r.isLocked, r.name, r.icon, r.link
end

function ArtifactInspect:GetPowers()
	return self:GetActiveArtifact().traits
end

function ArtifactInspect:GetPowerInfo(powerID)
	local a = self:GetActiveArtifact()
	for i, p in ipairs(self:GetActiveArtifact().traits) do
		if p.traitID == powerID then
			return p.spellID, a.powerForNextRank, p.currentRank, p.maxRank, p.bonusRanks, p.x, p.y, p.prereqsMet, p.isStart, p.isGold, p.isFinal
		end
	end
end

function ArtifactInspect:IsPowerKnown(powerID)
	local a = self:GetActiveArtifact()
	for i, p in ipairs(self:GetActiveArtifact().traits) do
		if p.traitID == powerID then
			return p.currentRank > 0
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Events

function ArtifactInspect:FS_MSG_AI_PROBE(_, _, _, sender)
	FS:Send("AI_PROBE_REPLY", not not Roster:PlayerArtifactData(), sender)
end

function ArtifactInspect:FS_MSG_AI_PROBE_REPLY(_, status)
	if status then
		Roster:SendMessage("FS_ARTIFACT_INSPECT_READY")
		self.inspectable = true
	else
		self.inspectable = false
	end
end

function ArtifactInspect:FS_MSG_AI_REQUEST(_, _, _, sender)
	FS:Send("AI_DATA", Roster:PlayerArtifactData(), sender)
end

function ArtifactInspect:FS_MSG_AI_DATA(_, data)
	self.data = data

	if data.active then
		self.active = data.active
	else
		for key in pairs(data) do
			if type(key) == "number" then
				self.active = key
				break
			end
		end
	end

	if FSArtifactFrame:IsShown() then
		FSArtifactFrame:Hide()
	end
	FSArtifactFrame:Show()
end

