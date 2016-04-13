local _, FS = ...
local Pacman = FS:RegisterModule("Pacman")

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceSerializer-3.0"):Embed(Pacman)
local Compress = LibStub:GetLibrary("LibCompress")

local Store
local string_char, bit_band, bit_lshift, bit_rshift = string.char, bit.band, bit.lshift, bit.rshift

-------------------------------------------------------------------------------
-- Utils
-------------------------------------------------------------------------------

function Pacman.printf(str, ...)
	print(("|cffffd200" .. str):format(...))
end

local bytetoB64 = {
	[0]="a","b","c","d","e","f","g","h",
	"i","j","k","l","m","n","o","p",
	"q","r","s","t","u","v","w","x",
	"y","z","A","B","C","D","E","F",
	"G","H","I","J","K","L","M","N",
	"O","P","Q","R","S","T","U","V",
	"W","X","Y","Z","0","1","2","3",
	"4","5","6","7","8","9","(",")"
}

local B64tobyte = {
	a =  0,  b =  1,  c =  2,  d =  3,  e =  4,  f =  5,  g =  6,  h =  7,
	i =  8,  j =  9,  k = 10,  l = 11,  m = 12,  n = 13,  o = 14,  p = 15,
	q = 16,  r = 17,  s = 18,  t = 19,  u = 20,  v = 21,  w = 22,  x = 23,
	y = 24,  z = 25,  A = 26,  B = 27,  C = 28,  D = 29,  E = 30,  F = 31,
	G = 32,  H = 33,  I = 34,  J = 35,  K = 36,  L = 37,  M = 38,  N = 39,
	O = 40,  P = 41,  Q = 42,  R = 43,  S = 44,  T = 45,  U = 46,  V = 47,
	W = 48,  X = 49,  Y = 50,  Z = 51,["0"]=52,["1"]=53,["2"]=54,["3"]=55,
	["4"]=56,["5"]=57,["6"]=58,["7"]=59,["8"]=60,["9"]=61,["("]=62,[")"]=63
}

-- This code is based on the Encode7Bit algorithm from LibCompress
-- Credit goes to Galmok (galmok@gmail.com)
local encodeB64Table = {};

local function encodeB64(str)
	local B64 = encodeB64Table
	local remainder = 0
	local remainder_length = 0
	local encoded_size = 0
	local l=#str
	local code
	for i=1,l do
		code = str:byte(i)
		remainder = remainder + bit_lshift(code, remainder_length)
		remainder_length = remainder_length + 8
		while(remainder_length) >= 6 do
			encoded_size = encoded_size + 1
			B64[encoded_size] = bytetoB64[bit_band(remainder, 63)]
			remainder = bit_rshift(remainder, 6)
			remainder_length = remainder_length - 6
		end
	end
	if remainder_length > 0 then
		encoded_size = encoded_size + 1
		B64[encoded_size] = bytetoB64[remainder]
	end
	return table.concat(B64, "", 1, encoded_size)
end

local decodeB64Table = {}

local function decodeB64(str)
	local bit8 = decodeB64Table
	local decoded_size = 0
	local ch
	local i = 1
	local bitfield_len = 0
	local bitfield = 0
	local l = #str
	while true do
		if bitfield_len >= 8 then
			decoded_size = decoded_size + 1
			bit8[decoded_size] = string_char(bit_band(bitfield, 255))
			bitfield = bit_rshift(bitfield, 8)
			bitfield_len = bitfield_len - 8
		end
		ch = B64tobyte[str:sub(i, i)]
		bitfield = bitfield + bit_lshift(ch or 0, bitfield_len)
		bitfield_len = bitfield_len + 6
		if i > l then
			break
		end
		i = i + 1
	end
	return table.concat(bit8, "", 1, decoded_size)
end

-------------------------------------------------------------------------------
-- Pacman config DB
-------------------------------------------------------------------------------

local pacman_default = {
	profile = {
		pkg = {
			["*"] = {
				db = {},
				enabled = false
			}
		}
	},
	global = {
		pkg = {
			["*"] = {
				db = {},
				push = false,
				trusted = {}
			}
		}
	}
}

local pacman_config = {
	title = {
		type = "description",
		name = "|cff64b4ffPacman",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "User-script package manager.\n",
		fontSize = "medium",
		order = 1
	},
	enable = {
		type = "toggle",
		name = "Enable",
		width = "full",
		get = function()
			return Pacman.settings.enable
		end,
		set = function(_, value)
			Pacman.settings.enable = value
			if value then
				Pacman:Enable()
			else
				Pacman:Disable()
			end
		end,
		order = 5
	},
}

-------------------------------------------------------------------------------
-- Sub-modules
-------------------------------------------------------------------------------

-- Construct the Store object
function Pacman:ConstructStore()
	if Store then return end
	Store = {}
	return Store
end

-- Create a new submodule
function Pacman:SubModule(name, ...)
	local submod = self:NewModule(name, ...)
	self[name] = submod
	return submod, Store
end

-------------------------------------------------------------------------------
-- Pacman Main GUI
-------------------------------------------------------------------------------

local pacman_installed_base = {
	title = {
		type = "description",
		name = "|cff64b4ffInstalled package",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "This tab displays the list of installed package.",
		fontSize = "medium",
		order = 1
	}
}

local pacman_installed = {
	name = "Installed",
	desc = "Installed Packages",
	order = 1,
	type = "group"
}

local pacman_updates = {
	name = "Updates",
	order = 2,
	type = "group",
	args = {
		title = {
			type = "description",
			name = "|cff64b4ffAvailable updates",
			fontSize = "large",
			order = 0
		},
		desc = {
			type = "description",
			name = "Manage and update your imported packages.",
			fontSize = "medium",
			order = 1
		}
	}
}

local pacman_new = {
	name = "Create package",
	desc = "Create a new package",
	order = 3,
	type = "group",
	args = {
		title = {
			type = "description",
			name = "|cff64b4ffCreate a new package",
			fontSize = "large",
			order = 0
		},
		desc = {
			type = "description",
			name = "\n",
			order = 1
		},
		identifier = {
			order = 2,
			name = "Package identifier",
			type = "input",
			width = "full",
			validate = function(_, id)
				if not Store:Get(id) then return true end
				return "A package with this ID already exists."
			end,
			set = function(_, id) Store:CreatePackage(id) end
		},
		identifier_d = {
			order = 3,
			name = "Example: |cffffd200Blash.T18.Archimonde.WroughtChaos",
			type = "description"
		},
	}
}

local import_data = ""
local pacman_import = {
	name = "Import package",
	desc = "Import a package from text data",
	order = 4,
	type = "group",
	args = {
		title = {
			type = "description",
			name = "|cff64b4ffImport package",
			fontSize = "large",
			order = 0
		},
		source = {
			order = 2,
			name = "Package code",
			type = "input",
			width = "full",
			multiline = 20,
			validate = function(_, src)
				src = decodeB64(src)
				src = Compress:Decompress(src)
				local res, pkg = Pacman:Deserialize(src)
				import_data = pkg
				if not res then
					return "Invalid data"
				elseif not Store:IsValid(pkg) then
					return "Invalid package."
				else
					local mine = Store:Get(pkg.id)
					if mine and mine.uuid ~= pkg.uuid then
						return "A package with this ID already exists."
					else
						return true
					end
				end
			end,
			set = function() Pacman.Updater:Upgrade(import_data) end
		},
	}
}

local pacman_options = {
	name = "Options",
	order = 10,
	type = "group",
	args = {

	}
}

local pacman_gui = {
	title = {
			type = "description",
			name = " |cff64b4ffPacman",
			fontSize = "large",
			order = 0
	},
	desc = {
		type = "description",
		name = " Lua package manager\n",
		fontSize = "medium",
		order = 1
	},
	packages = pacman_installed,
	--updates = pacman_updates,
	new = pacman_new,
	import = pacman_import,
	--options = pacman_options
}

local pacman_fs_opts = {
	title = {
		type = "description",
		name = "|cff64b4ffPacman",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Lua package manager\n",
		fontSize = "medium",
		order = 1
	},
	notice = {
		type = "description",
		name = "|cff999999This module is exceptionally complex and has a dedicated configuration interface.\n",
		order = 6
	},
	--packages = pacman_installed,
	--updates = pacman_updates,
	--new = pacman_new,
	--options = pacman_options,
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	docs = FS.Config:MakeDoc("Available chat commands", 2000, {
		{"", "Open Pacman standalone interface.\nAlso available as /pm."},
		{"list", "List installed package status."},
		{"update", "Open the package updater window."},
		{"enable|disable <package-id>", "Enable or disable the given package."},
		{"view|edit <package-id>", "Open the package editor to view or edit the given package."},
	}, "/pacman ")
}

-------------------------------------------------------------------------------
-- Life-cycle events
-------------------------------------------------------------------------------

function Pacman:OnInitialize()
	-- Settings
	self.db = FS.db:RegisterNamespace("Pacman", pacman_default)
	self.settings = self.db.profile

	-- Initialize Store
	Store:OnInitialize()

	-- Profile switch
	pacman_gui.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(FS.db)

	-- Register options table
	AceConfig:RegisterOptionsTable("Pacman", { type = "group", args = pacman_gui })
	FS.Config:Register("Pacman", pacman_fs_opts)
end

function Pacman:OnEnable()
	self:RegisterMessage("PACMAN_STORE_UPDATED", "UpdatePackageList")
	Store:OnEnable()

	-- TODO: Remove
	Pacman.Store = Store
end

function Pacman:NotifyLoaded(name)
	C_Timer.After(1, function()
		for _, frame in ipairs({ GetFramesRegisteredForEvent("ADDON_LOADED") }) do
			local handler = frame:GetScript("OnEvent")
			if handler then handler(frame, "ADDON_LOADED", name) end
		end
	end)
end

-------------------------------------------------------------------------------
-- Package list
-------------------------------------------------------------------------------

local function create_package_gui(pkg, valid)
	local own = pkg.author_key == FS:PlayerKey()

	if not valid then
		return {
			title = {
				type = "description",
				name = "|cffff0000" .. pkg.id,
				fontSize = "large",
				order = 0
			},
			desc = {
				type = "description",
				name = "\nThis package is corrupted and cannot be loaded.\n",
				fontSize = "medium",
				order = 1
			},
			delete = {
				type = "execute",
				name = "Delete",
				desc = "Remove this package from your game.",
				order = 10,
				width = "half",
				confirm = true,
				confirmText = "The package '|cff64b4ff" .. pkg.id .. "|r' will be removed",
				func = function() Store:RemovePackage(pkg) end
			}
		}
	end

	local status = Store:Status(pkg)
	local exported = false
	local o
	o = {
		title = {
			type = "description",
			name = "|cff64b4ff" .. pkg.id,
			fontSize = "large",
			order = 0
		},
		desc = {
			type = "description",
			name = pkg.desc .. "\n",
			fontSize = "medium",
			order = 1
		},
		enabled = {
			type = "toggle",
			name = "Enable package",
			desc = "This package will be loaded when you enter the world.",
			order = 2,
			get = function() return Store:IsEnabled(pkg) end,
			set = function(_, s)
				if s then
					Store:EnablePackage(pkg)
				else
					Store:DisablePackage(pkg)
				end
			end
		},
		auto_update = {
			type = "toggle",
			name = "Enable push-updates",
			desc = "Push-updates will be enabled for this package.",
			order = 3,
			get = function() return status.global.push end,
			set = function(_, s) status.global.push = s end
		},
		--[[enabled_desc = {
			type = "description",
			name = "|cff999999This package will be automatically loaded when you launch the game.\n" ..
					"Note that it may use lazy loading to defer actual loading until needed.\n",
			order = 4
		},]]
		operations = {
			type = "group",
			inline = true,
			name = "Operations",
			order = 11,
			args = {
				edit = {
					type = "execute",
					name = function() return own and "Edit" or "View" end,
					desc = "Open the package editor to view and edit its content",
					order = 0,
					width = "half",
					func = function() Pacman.Editor:Open(pkg, not own, pkg.id) end
				},
				share = {
					type = "execute",
					name = "Share",
					desc = "Link this package to other players",
					order = 2,
					width = "half",
					hidden = not pkg.flags.Shareable and not own,
					func = function() Pacman.Updater:SharePackage(pkg) end
				},
				export = {
					type = "execute",
					name = "Export",
					desc = "Export this package as text",
					order = 10,
					order = 2.5,
					width = "half",
					hidden = not pkg.flags.Shareable and not own,
					func = function() exported = not exported end
				},
				update = {
					type = "execute",
					name = "Update",
					desc = "Open the update manager to update, push or view other players' package version",
					order = 3,
					width = "half",
					func = function() Pacman.Updater:Queue("updater", pkg.id) end
				},
				remove = {
					type = "execute",
					name = "Remove",
					desc = "Remove this package from your game",
					order = 10,
					width = "half",
					confirm = true,
					confirmText = "The package '|cff64b4ff" .. pkg.id .. "|r' will be removed",
					func = function() Store:RemovePackage(pkg) end
				},
			}
		},
		export = {
			type = "group",
			inline = true,
			name = "Export",
			order = 15,
			hidden = function() return not exported or (not pkg.flags.Shareable and not own) end,
			args = {
				data = {
					type = "input",
					name = "",
					multiline = true,
					width = "full",
					get = function()
						exported = false
						local cln = Store:Export(pkg)
						local serialized = Pacman:Serialize(cln)
						serialized = Compress:CompressHuffman(serialized)
						return encodeB64(serialized)
					end
				}
			}
		},
		meta = {
			type = "group",
			inline = true,
			name = "Metadata",
			order = 20,
			args = {
				author = {
					type = "description",
					name = "|cffffd200Author|r\n" .. pkg.author,
					order = 10
				},
				revision = {
					type = "description",
					name = "\n|cffffd200Revision|r\n" .. pkg.revision .. "  @  " .. pkg.revision_date,
					order = 15
				},
				flags = {
					type = "description",
					name = function()
						local flags = ""
						for flag in pairs(pkg.flags) do
							if flags == "" then
								flags = flag
							else
								flags = flags .. ", " .. flag
							end
						end
						if flags == "" then
							flags = "None"
						end
						return "\n|cffffd200Flags|r\n" .. flags
					end,
					order = 18
				},
				--[[editable = {
					type = "description",
					name = "\n|cffffd200Editable|r\n" .. (own and "Yes" or "No"),
					order = 20
				},]]
				spacing = {
					type = "description",
					name = "",
					fontSize = "small",
					order = 25
				}
			}
		},
		trusted = {
			type = "group",
			inline = true,
			name = "Trusted players",
			order = 25,
			args = {
				list = {
					type = "description",
					name = function()
						local trusteds = ""
						for trusted in pairs(status.global.trusted) do
							if trusteds == "" then
								trusteds = trusted
							else
								trusteds = trusteds .. ", " .. trusted
							end
						end
						if trusteds == "" then
							trusteds = "None"
						end
						return trusteds .. "\n"
					end,
					order = 19
				},
				clear_trusted = {
					type = "execute",
					name = "Clear",
					desc = "Clear the list of trusted players.",
					order = 20,
					width = "half",
					func = function() wipe(status.global.trusted) end
				},
			}
		},
		clone = {
			type = "group",
			inline = true,
			name = "Clone this package",
			order = 30,
			hidden = not own and pkg.flags.Unclonable,
			args = {
				desc = {
					type = "description",
					name =
						"You can clone this package into a new one, allowing you to edit the package even if you are not the original author. " ..
						"However, you will no longer be able to receive updates for this package.\n",
					order = 1
				},
				revision = {
					type = "input",
					name = "New package id",
					width = "full",
					set = function(_, id) Store:ClonePackage(pkg, id) end,
					order = 15
				},
				spacing = {
					type = "description",
					name = "",
					fontSize = "small",
					order = 25
				}
			}
		},
		uuid = {
			type = "group",
			inline = true,
			name = "Package UUID",
			order = 100,
			args = {
				id = {
					type = "input",
					name = "",
					get = function() return pkg.uuid end,
					width = "full",
					order = 20
				}
			}
		}
	}

	if pkg.flags.Configurable and status.loaded then
		local env = Pacman.Sandbox:GetEnvironment(pkg)
		local conf_table = env.locals.config
		if conf_table then
			o.pkg_conf = {
				type = "group",
				inline = true,
				name = "Package configuration",
				order = 9,
				args = conf_table
			}
			--[[o.pkg_conf_spacing = {
				type = "description",
				name = " ",
				order = 10
			}]]
		end
	end

	return o
end

function Pacman:UpdatePackageList()
	local pkgs = {}
	for k, v in pairs(pacman_installed_base) do pkgs[k] = v end

	local suffix = 0
	local function push(node, key, pkg, prefix)
		local head, tail = key:match("([^.]+)%.(.+)")
		if head then
			local sub_node = node[head]
			if not sub_node then
				sub_node = {
					type = "group",
					name = head,
					desc = (prefix .. head):lower(),
					args = {}
				}
				node[head] = sub_node
			end
			push(sub_node.args, tail, pkg, prefix .. head .. ".")
		else
			suffix = suffix + 1

			local valid = Store:IsValid(pkg)
			local color = "|cff999999"
			if not valid then
				color = "|cffff0000"
			elseif Store:IsEnabled(pkg) then
				color = "|cff64b4ff"
			end

			node[key .. suffix] = {
				type = "group",
				name = color .. key,
				desc = (prefix .. key):lower(),
				args = create_package_gui(pkg, valid)
			}
		end
	end

	for uuid, pkg in Store:Packages() do
		push(pkgs, pkg.id, pkg, "")
	end

	pacman_installed.args = pkgs
end

function Pacman:OpenGUI()
	self:UpdatePackageList()
	AceConfigDialog:Open("Pacman")
end
