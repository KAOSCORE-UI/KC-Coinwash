fx_version 'cerulean'
game 'gta5'

author 'KC-Coinwash'
description 'Money Laundering System - Framework & Inventory Agnostic'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua', -- remove if not using ox_lib
    'config/config.lua',
    'config/framework_bridge.lua',
}

client_scripts {
    'client/main.lua',
    'client/admin.lua',
    'client/nui.lua',
}

server_scripts {
    'server/main.lua',
    'server/framework_bridge.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/js/admin.js',
}

lua54 'yes'
