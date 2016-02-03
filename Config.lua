local _, FS = ...
local Config = FS:RegisterModule("Config")

local AceConfig = LibStub("AceConfig-3.0")

local options = {
	type = "group",
	args = {
		About = {
			name = "About",
			order = 1,
			type = "group",
			args = {
				title = {
					type = "description",
					name = "|cff64b4ffFS Core",
					fontSize = "large",
					order = 0
				},
				desc = {
					type = "description",
					name = "FS Core provides a framework to build powerful addons, WeakAuras and enhancing boss mods for high-end raiding.",
					fontSize = "medium",
					order = 1
				},
				author = {
					type = "description",
					name = "\n|cffffd100Author: |r Blash @ EU-Sargeras",
					order = 2
				},
				version = {
					type = "description",
					name = "|cffffd100Version: |r" .. FS.version,
					order = 3
				},
				player_key = {
					type = "description",
					name = function()
						return "|cffffd100\nPlayer key:\n|r" .. FS:Wrap(FS:PlayerKey(), 40)
					end,
					order = 4
				}
			}
		}
	}
}

function Config:OnInitialize()
	AceConfig:RegisterOptionsTable("FS Core", options)
end

function Config:OnEnable()
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(FS.db)
end

function Config:Register(title, config)
	options.args[title] = {
		name = title,
		order = 10,
		type = "group",
		args = config
	}
end

function Config:MakeDoc(title, order, fields, prefix)
	local output = {
		type = "group",
		name = "|cff64b4ff" .. title,
		inline = true,
		order = order,
		args = {}
	}
	
	local order = 1
	for _, field in ipairs(fields) do
		local title_order = order
		local desc_order = order + 1
		order = order + 2
		
		local title = prefix and "|cffff7d0a" .. prefix or ""
		title = title .. "|cfffff569" .. field[1]
		
		output.args["item_" .. title_order] = {
			type = "description",
			name = title,
			fontSize = "medium",
			order = title_order
		}
		
		output.args["item_" .. desc_order] = {
			type = "description",
			name = field[2] .. "\n",
			order = desc_order
		}
	end
	
	return output
end
