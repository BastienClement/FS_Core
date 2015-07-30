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
					name = "FS Core provides a framework to construct powerful addons, WeakAuras and enhancing boss mods for high-end raiding.",
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
