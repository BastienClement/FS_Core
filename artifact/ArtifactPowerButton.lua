local _, FS = ...
local AI = FS.ArtifactInspect

FSArtifactPowerButtonMixin = {}
local FSArtifactPowerButtonMixin = FSArtifactPowerButtonMixin

function FSArtifactPowerButtonMixin:SetupButton(powerID, anchorRegion)
	local spellID, cost, currentRank, maxRank, bonusRanks, x, y, prereqsMet, isStart, isGoldMedal, isFinal = AI:GetPowerInfo(powerID)
	self:ClearAllPoints()
	self:SetPoint("CENTER", anchorRegion, "TOPLEFT", x * anchorRegion:GetWidth(), -y * anchorRegion:GetHeight())

	local name, _, texture = GetSpellInfo(spellID)
	self.Icon:SetTexture(texture)
	self.IconDesaturated:SetTexture(texture)

	self.powerID = powerID
	self.spellID = spellID
	self.currentRank = currentRank
	self.bonusRanks = bonusRanks
	self.maxRank = maxRank
	self.isStart = isStart
	self.isGoldMedal = isGoldMedal
	self.isFinal = isFinal

	self.isCompletelyPurchased = currentRank == maxRank or self.isStart
	self.hasSpentAny = currentRank > bonusRanks
	self.couldSpendPoints = false
	self.isMaxRank = currentRank == maxRank
	self.prereqsMet = prereqsMet
	self.wasBonusRankJustIncreased = false
	self.cost = cost

	self:UpdatePowerType()
	self:EvaluateStyle()
end

function FSArtifactPowerButtonMixin:EvaluateStyle()
	if AI:IsPowerKnown(self.powerID) then
		self:SetStyle(ARTIFACT_POWER_STYLE_PURCHASED_READ_ONLY)
	else
		self:SetStyle(ARTIFACT_POWER_STYLE_UNPURCHASED_READ_ONLY)
	end
end

FSArtifactPowerButtonMixin.OnEnter = ArtifactPowerButtonMixin.OnEnter
FSArtifactPowerButtonMixin.SetStyle = ArtifactPowerButtonMixin.SetStyle
FSArtifactPowerButtonMixin.UpdatePowerType = ArtifactPowerButtonMixin.UpdatePowerType
FSArtifactPowerButtonMixin.ClearOldData = ArtifactPowerButtonMixin.ClearOldData
FSArtifactPowerButtonMixin.GetPowerID = ArtifactPowerButtonMixin.GetPowerID
FSArtifactPowerButtonMixin.IsStart = ArtifactPowerButtonMixin.IsStart
FSArtifactPowerButtonMixin.IsFinal = ArtifactPowerButtonMixin.IsFinal
FSArtifactPowerButtonMixin.IsGoldMedal = ArtifactPowerButtonMixin.IsGoldMedal
FSArtifactPowerButtonMixin.IsCompletelyPurchased = ArtifactPowerButtonMixin.IsCompletelyPurchased
FSArtifactPowerButtonMixin.ApplyRelicType = ArtifactPowerButtonMixin.ApplyRelicType
FSArtifactPowerButtonMixin.RemoveRelicType = ArtifactPowerButtonMixin.RemoveRelicType
FSArtifactPowerButtonMixin.SetRelicHighlightEnabled = ArtifactPowerButtonMixin.SetRelicHighlightEnabled

function FSArtifactPowerButtonMixin:StopAllAnimations() end
