local _, FS = ...
local AI = FS.ArtifactInspect

local AceGUI = LibStub("AceGUI-3.0")
local selector = AceGUI:Create("Dropdown")

selector:SetCallback("OnValueChanged", function(_, _, artifact)
	AI.active = artifact
	FSArtifactFrame.PerksTab:Refresh()
end)

FS_ARTIFACT_UNINSPECTABLE = "This player's artifact cannot be inspected"

FSArtifactUIMixin = {}
local FSArtifactUIMixin = FSArtifactUIMixin

function FSArtifactUIMixin:OnLoad()
	selector.frame:SetParent(self)
	selector.frame:SetFrameStrata("FULLSCREEN")
	selector:SetWidth(150)
	selector:SetPoint("TOPLEFT", 90, -62)
end

function FSArtifactUIMixin:OnShow()
	if AI:HasData() then
		local artifacts = {}
		for key, data in pairs(AI.data) do
			if type(data) == "table" and data.name then
				artifacts[key] = "|T" .. data.icon .. ":16|t " .. data.name
			end
		end

		selector:SetList(artifacts)
		selector:SetValue(AI.data.active)

		self:SetupPerArtifactData()
		self.Uninspectable:Hide()
		self.PerksTab:Show()
	else
		self.Uninspectable:Show()
		self.PerksTab:Hide()
	end
end

function FSArtifactUIMixin:SetupPerArtifactData()
	local textureKit, titleName, titleR, titleG, titleB, barConnectedR, barConnectedG, barConnectedB, barDisconnectedR, barDisconnectedG, barDisconnectedB = AI:GetArtifactArtInfo()
	if textureKit then
		local classBadgeTexture = ("%s-ClassBadge"):format(textureKit)
		self.ForgeBadgeFrame.ForgeClassBadgeIcon:SetAtlas(classBadgeTexture, true)
	end
end

function FSArtifactUIMixin:OnHide()
end

function FSArtifactUIMixin:Refresh()
	self:RefreshKnowledgeRanks()
end

function FSArtifactUIMixin:RefreshKnowledgeRanks()
	local totalRanks = AI:GetTotalPurchasedRanks()
	if totalRanks > 0 then
		self.ForgeBadgeFrame.ForgeLevelLabel:SetText(totalRanks)
		self.ForgeBadgeFrame.ForgeLevelLabel:Show()
		self.ForgeBadgeFrame.ForgeLevelBackground:Show()
		self.ForgeBadgeFrame.ForgeLevelBackgroundBlack:Show()
		self.ForgeLevelFrame:Show()
	else
		self.ForgeBadgeFrame.ForgeLevelLabel:Hide()
		self.ForgeBadgeFrame.ForgeLevelBackground:Hide()
		self.ForgeBadgeFrame.ForgeLevelBackgroundBlack:Hide()
		self.ForgeLevelFrame:Hide()
		self.KnowledgeLevelHelpBox:Hide()
	end
end

local function formatBigNumber(num)
	num = tostring(num)
	local len = #num
	local res = ""
	for j = 0, len - 1 do
		local i = len - j
		if j > 0 and j % 3 == 0 then
			res = "," .. res
		end
		res = num:sub(i, i) .. res
	end
	return res
end

function FSArtifactUIMixin:OnKnowledgeEnter(knowledgeFrame)
	GameTooltip:SetOwner(knowledgeFrame, "ANCHOR_BOTTOMRIGHT", -25, 27)
	local textureKit, titleName, titleR, titleG, titleB, barConnectedR, barConnectedG, barConnectedB, barDisconnectedR, barDisconnectedG, barDisconnectedB = AI:GetArtifactArtInfo()
	GameTooltip:SetText(titleName, titleR, titleG, titleB)

	local a = AI:GetActiveArtifact()

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Available artifact power:", HIGHLIGHT_FONT_COLOR:GetRGB())
	GameTooltip:AddLine(("%s / %s"):format(formatBigNumber(a.unspentPower), formatBigNumber(a.maxPower)))

	local knowledgeLevel = AI:GetArtifactKnowledgeLevel()
	if knowledgeLevel then
		local knowledgeMultiplier = AI:GetArtifactKnowledgeMultiplier()
		local percentIncrease = math.floor(((knowledgeMultiplier - 1.0) * 100) + .5)

		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(ARTIFACTS_KNOWLEDGE_TOOLTIP_LEVEL:format(knowledgeLevel), HIGHLIGHT_FONT_COLOR:GetRGB())
		GameTooltip:AddLine(ARTIFACTS_KNOWLEDGE_TOOLTIP_DESC:format(BreakUpLargeNumbers(percentIncrease)), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end

	GameTooltip:Show();
end
