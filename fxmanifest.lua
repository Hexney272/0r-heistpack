fx_version "cerulean"
lua54 "yes"
game "gta5"
name "RealRPG-heistpack"
author "RealRPG"
version "1.0.8"
description "RealRPG Heist Pack"

shared_scripts {
	"@ox_lib/init.lua",
	"config/main.lua",
	"modules/init.lua",
}

files {
	"locales/*.json",
	"config/**/*.lua",
	"modules/**/client.lua",
	"modules/framework/init.lua",
	"core/heist/scenario_registry.lua",
	"core/scenarios/_shared/client/*.lua",
	"ui/build/index.html",
	"ui/build/**/*",
}

client_scripts {
	"console_filter.lua",  -- Load FIRST to filter console spam
	"core/**/client.lua",
	"client.lua",
}

server_scripts {
	"@oxmysql/lib/MySQL.lua",
	"core/**/server.lua",
	"server.lua",
}

ui_page "ui/build/index.html"

dependencies {
	"ox_lib",
	"oxmysql",
	"0r_lib"
}
