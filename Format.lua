local _, FS = ...

function FS:Round(val, decimal)
	if decimal then
		return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
	else
		return math.floor(val+0.5)
	end
end

function FS:ShortenNumber(value, decimal)
	if not value then return end
	if(value > 999999999) then return self:Round(value/1000000000, decimal), "B" end
	if(value > 999999) then return self:Round(value/1000000, decimal), "M" end
	if(value > 999) then return self:Round(value/1000, decimal), "k" end
	return value, ""
end

function FS:FormatNumber(value, decimal, pattern)
	if not value then return end
	return (pattern or "%s%s"):format(self:ShortenNumber(value, decimal))
end

function FS:GetClassColor(unit, components)
	local target_class = select(2, UnitClass(unit))
	if target_class then
		if components then
			local color = RAID_CLASS_COLORS[target_class]
			return color.r, color.g, color.b, 1
		else
			return RAID_CLASS_COLORS[target_class].colorStr
		end
	else
		if components then
			return 1, 1, 1, 1
		else
			return "ffffffff"
		end
	end
end

local icn_string = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:%s|t"
function FS:Icon(index, align)
	if not index then return "" end
	return icn_string:format(index, align or "0")
end
