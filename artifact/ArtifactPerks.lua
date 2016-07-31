local _, FS = ...
local AI = FS.ArtifactInspect

FSArtifactPerksMixin = {}
local FSArtifactPerksMixin = FSArtifactPerksMixin

function FSArtifactPerksMixin:OnShow()
	self:Refresh()
end

function FSArtifactPerksMixin:Refresh()
	FSArtifactFrame:Refresh()
	self:RefreshBackground()
	self:RefreshModel()
	self.TitleContainer:Refresh()
	self:HideAllLines()
	self:RefreshPower()
end

function FSArtifactPerksMixin:RefreshBackground()
	local textureKit, titleName, titleR, titleG, titleB, barConnectedR, barConnectedG, barConnectedB, barDisconnectedR, barDisconnectedG, barDisconnectedB = AI:GetArtifactArtInfo()
	if textureKit then
		local bgAtlas = ("%s-BG"):format(textureKit);
		self.BackgroundBack:SetAtlas(bgAtlas);
		self.Model.BackgroundFront:SetAtlas(bgAtlas);
	end
end

function FSArtifactPerksMixin:RefreshModel()
	local itemID, altItemID, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop = AI:GetArtifactInfo()
	local uiCameraID, altHandUICameraID, modelAlpha, modelDesaturation, suppressGlobalAnim = AI:GetAppearanceInfo()

	self.Model.uiCameraID = uiCameraID
	self.Model.desaturation = modelDesaturation
	if itemAppearanceID then
		self.Model:SetItemAppearance(itemAppearanceID)
	else
		self.Model:SetItem(itemID, appearanceModID)
	end

	self.Model.BackgroundFront:SetAlpha(1.0 - (modelAlpha or 1.0))

	self.Model:SetModelDrawLayer(altOnTop and "BORDER" or "ARTWORK")
	self.AltModel:SetModelDrawLayer(altOnTop and "ARTWORK" or "BORDER")

	self.Model:SetSuppressGlobalAnimationTrack(suppressGlobalAnim)
	self.AltModel:SetSuppressGlobalAnimationTrack(suppressGlobalAnim)

	if altItemID and altHandUICameraID then
		self.AltModel.uiCameraID = altHandUICameraID
		self.AltModel.desaturation = modelDesaturation
		if altItemAppearanceID then
			self.AltModel:SetItemAppearance(altItemAppearanceID)
		else
			self.AltModel:SetItem(altItemID, appearanceModID)
		end
		self.AltModel:Show()
	else
		self.AltModel:Hide()
	end
end

function FSArtifactPerksMixin:RefreshPower()
	self.powerIDToPowerButton = {}

	self.startingPowerButton = nil
	self.finalPowerButton = nil

	local powers = AI:GetPowers()

	-- Determine if all Gold Medal traits are fully purchased to determine when the final power should be shown
	local areAllGoldMedalsPurchased = true
	for i, power in ipairs(powers) do
		local powerID = power.traitID
		local powerButton = self.powerIDToPowerButton[powerID]

		if not powerButton then
			powerButton = self:GetOrCreatePowerButton(i)
			self.powerIDToPowerButton[powerID] = powerButton
			powerButton:ClearOldData()
		end

		powerButton:SetupButton(powerID, self.BackgroundBack)
		powerButton.links = {}
		powerButton.owner = self

		if powerButton:IsStart() then
			self.startingPowerButton = powerButton
		elseif powerButton:IsFinal() then
			self.finalPowerButton = powerButton
		elseif powerButton:IsGoldMedal() then
			if not powerButton:IsCompletelyPurchased() then
				areAllGoldMedalsPurchased = false
			end
		end

		powerButton:Show();
	end

	if self.finalPowerButton then
			self.finalPowerButton:Hide();
	end

	self:HideUnusedWidgets(self.PowerButtons, #powers)
	self:RefreshDependencies(powers)
	--self:RefreshRelics()
end

function FSArtifactPerksMixin:GetOrCreatePowerButton(powerIndex)
	local button = self.PowerButtons and self.PowerButtons[powerIndex]
	if button then return button end
	return CreateFrame("BUTTON", nil, self, "FSArtifactPowerButtonTemplate");
end

local function OnUnusedLineHidden(lineContainer)
	lineContainer.Background:SetAlpha(0.0)
	lineContainer.Fill:SetAlpha(0.0)
	lineContainer.FillScroll1:SetAlpha(0.0)
	lineContainer.FillScroll2:SetAlpha(0.0)
end

function FSArtifactPerksMixin:RefreshDependencies(powers)
	local numUsedLines = 0

	local textureKit, titleName, titleR, titleG, titleB, barConnectedR, barConnectedG, barConnectedB, barDisconnectedR, barDisconnectedG, barDisconnectedB = AI:GetArtifactArtInfo()
	for i, fromPower in ipairs(powers) do
		local fromPowerID = fromPower.traitID
		local fromButton = self.powerIDToPowerButton[fromPowerID]
		local fromLinks = fromPower.links
		if fromLinks then
			for j, toPowerID in ipairs(fromLinks) do
				if not fromButton.links[toPowerID] then
					local toButton = self.powerIDToPowerButton[toPowerID]
					if toButton and not toButton.links[fromPowerID] then
						numUsedLines = numUsedLines + 1
						local lineContainer = self:GetOrCreateDependencyLine(numUsedLines)

						lineContainer.Fill:SetStartPoint("CENTER", fromButton)
						lineContainer.Fill:SetEndPoint("CENTER", toButton)
						lineContainer.FillScroll1:SetStartPoint("CENTER", fromButton)
						lineContainer.FillScroll1:SetEndPoint("CENTER", toButton)
						lineContainer.FillScroll2:SetStartPoint("CENTER", fromButton)
						lineContainer.FillScroll2:SetEndPoint("CENTER", toButton)

						lineContainer.Fill:SetAlpha(1.0)
						lineContainer.FillScroll1:SetAlpha(1.0)
						lineContainer.FillScroll2:SetAlpha(1.0)

						if (fromButton.isCompletelyPurchased and toButton.hasSpentAny) or (toButton.isCompletelyPurchased and fromButton.hasSpentAny) then
							lineContainer.Fill:SetVertexColor(barConnectedR, barConnectedG, barConnectedB)
							lineContainer.FillScroll1:SetVertexColor(barConnectedR, barConnectedG, barConnectedB)
							lineContainer.FillScroll2:SetVertexColor(barConnectedR, barConnectedG, barConnectedB)
							lineContainer.ScrollAnim:Play()
						else
							local avg = 0.2126 * barConnectedR + 0.7152 * barConnectedG + 0.0722 * barConnectedB
							local r = (avg + barConnectedR) / 4
							local g = (avg + barConnectedG) / 4
							local b = (avg + barConnectedB) / 4
							lineContainer.Fill:SetVertexColor(r, g, b)
							lineContainer.FillScroll1:SetVertexColor(r, g, b)
							lineContainer.FillScroll2:SetVertexColor(r, g, b)
							lineContainer.ScrollAnim:Stop()
						end

						fromButton.links[toPowerID] = lineContainer
						toButton.links[fromPowerID] = lineContainer
					end
				end
			end
		end
	end

	self:HideUnusedWidgets(self.DependencyLines, numUsedLines, OnUnusedLineHidden);
end

FSArtifactPerksMixin.HideAllLines = ArtifactPerksMixin.HideAllLines
FSArtifactPerksMixin.GetOrCreateDependencyLine = ArtifactPerksMixin.GetOrCreateDependencyLine
FSArtifactPerksMixin.HideUnusedWidgets = ArtifactPerksMixin.HideUnusedWidgets

------------------------------------------------------------------
-- ArtifactTitleTemplate
------------------------------------------------------------------

FSArtifactTitleTemplateMixin = {}
local FSArtifactTitleTemplateMixin = FSArtifactTitleTemplateMixin

function FSArtifactTitleTemplateMixin:Refresh()
	self:RefreshTitle()
	self:EvaluateRelics()
	self:SetPointsRemaining(AI:GetPointsRemaining())
end

function FSArtifactTitleTemplateMixin:RefreshTitle()
	local textureKit, titleName, titleR, titleG, titleB, barConnectedR, barConnectedG, barConnectedB, barDisconnectedR, barDisconnectedG, barDisconnectedB = AI:GetArtifactArtInfo()
	self.ArtifactName:SetText(titleName)
	self.ArtifactName:SetVertexColor(titleR, titleG, titleB)

	if textureKit then
		local headerAtlas = ("%s-Header"):format(textureKit)
		self.Background:SetAtlas(headerAtlas, true)
		self.Background:Show()
	else
		self.Background:Hide()
	end
end

function FSArtifactTitleTemplateMixin:EvaluateRelics()
	local numRelicSlots = AI:GetNumRelicSlots()
	self:SetHeight(140)

	for i = 1, numRelicSlots do
		local relicSlot = self.RelicSlots[i]
		local relicType = AI:GetRelicSlotType(i)

		local relicAtlasName = ("Relic-%s-Slot"):format(relicType)
		relicSlot:GetNormalTexture():SetAtlas(relicAtlasName, true)
		relicSlot.GlowBorder1:SetAtlas(relicAtlasName, true)
		relicSlot.GlowBorder2:SetAtlas(relicAtlasName, true)
		relicSlot.GlowBorder3:SetAtlas(relicAtlasName, true)
		local locked, relicName, relicIcon, relicLink = AI:GetRelicInfo(i)
		if locked then
			relicSlot:GetNormalTexture():SetAlpha(.5)
			relicSlot:Disable()
			relicSlot.LockedIcon:Show()
			relicSlot.Icon:SetMask(nil)
			relicSlot.Icon:SetAtlas("Relic-SlotBG", true)
			relicSlot.Glass:Hide()
		else
			relicSlot:GetNormalTexture():SetAlpha(1)
			relicSlot:Enable()
			relicSlot.LockedIcon:Hide()
			if relicIcon then
				relicSlot.Icon:SetSize(34, 34)
				relicSlot.Icon:SetMask(nil)
				relicSlot.Icon:SetTexCoord(0, 1, 0, 1)
				relicSlot.Icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
				relicSlot.Icon:SetTexture(relicIcon)
				relicSlot.Glass:Show()
			else
				relicSlot.Icon:SetMask(nil)
				relicSlot.Icon:SetAtlas("Relic-SlotBG", true)
				relicSlot.Glass:Hide()
			end
		end

		relicSlot.relicLink = relicLink
		relicSlot.relicType = relicType
		relicSlot.relicSlotIndex = i
		relicSlot.lockedReason = locked

		relicSlot:ClearAllPoints()
		local PADDING = 0
		if i == 1 then
			local offsetX = -(numRelicSlots - 1) * (relicSlot:GetWidth() + PADDING) * .5
			relicSlot:SetPoint("CENTER", self, "CENTER", offsetX, -6)
		else
			relicSlot:SetPoint("LEFT", self.RelicSlots[i - 1], "RIGHT", PADDING, 0)
		end

		relicSlot:Show()
	end

	for i = numRelicSlots + 1, #self.RelicSlots do
		self.RelicSlots[i]:Hide()
	end
end

function FSArtifactTitleTemplateMixin:SetPointsRemaining(value)
	self.PointsRemainingLabel:SetText(value)
end

function FSArtifactTitleTemplateMixin:OnRelicSlotMouseEnter(relicSlot)
	if relicSlot.lockedReason then
		GameTooltip:SetOwner(relicSlot, "ANCHOR_BOTTOMRIGHT", 0, 10)
		local slotName = _G["RELIC_SLOT_TYPE_" .. relicSlot.relicType:upper()]
		if slotName then
			GameTooltip:SetText(LOCKED_RELIC_TOOLTIP_TITLE:format(slotName), 1, 1, 1)
			GameTooltip:AddLine(LOCKED_RELIC_TOOLTIP_BODY, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
			GameTooltip:Show()
		end
	elseif relicSlot.relicLink then
		GameTooltip:SetOwner(relicSlot, "ANCHOR_BOTTOMRIGHT", 0, 10)
		GameTooltip:SetHyperlink(relicSlot.relicLink)
	elseif relicSlot.relicType then
		GameTooltip:SetOwner(relicSlot, "ANCHOR_BOTTOMRIGHT", 0, 10)
		local slotName = _G["RELIC_SLOT_TYPE_" .. relicSlot.relicType:upper()]
		if slotName then
			GameTooltip:SetText(EMPTY_RELIC_TOOLTIP_TITLE:format(slotName), 1, 1, 1)
			GameTooltip:AddLine(EMPTY_RELIC_TOOLTIP_BODY:format(slotName), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
			GameTooltip:Show()
		end
	end
end

function FSArtifactTitleTemplateMixin:OnRelicSlotMouseLeave(relicSlot)
	GameTooltip_Hide()
end

function FSArtifactTitleTemplateMixin:OnRelicSlotClicked(relicSlot)
end
