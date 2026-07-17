-- ╔══════════════════════════════════════════════╗
-- ║         KC-COINWASH - ADMIN CLIENT             ║
-- ╚══════════════════════════════════════════════╝

local adminUIOpen = false

-- ─── ADMIN TABLET COMMAND ────────────────────────────────────────────────────
RegisterCommand('washadmin', function()
    TriggerServerEvent('KC-Coinwash:requestSync')
    Wait(300)
    -- Ask server to confirm admin and send washer list
    TriggerServerEvent('KC-Coinwash:adminGetWashers')
end, false)

-- Open admin tablet once server confirms washer list
RegisterNetEvent('KC-Coinwash:adminWasherList', function(washerList)
    if adminUIOpen then return end
    adminUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action   = 'openAdmin',
        washers  = washerList,
        config   = {
            washFee      = Config.WashFee,
            washDuration = Config.WashDuration,
            maxWash      = Config.MaxWash,
            minWash      = Config.MinWash,
            riskLevel    = Config.DefaultRiskLevel,
            propModel    = Config.WasherProp,
        },
    })
end)

-- ─── NUI → ADMIN CALLBACKS ────────────────────────────────────────────────────

-- Place washer at player position
RegisterNUICallback('placeWasher', function(data, cb)
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local label   = data.label or ('Washer #' .. os.time())
    TriggerServerEvent('KC-Coinwash:placeWasher', { x = coords.x, y = coords.y, z = coords.z }, heading, label)
    cb('ok')
end)

-- Remove washer by id
RegisterNUICallback('removeWasher', function(data, cb)
    TriggerServerEvent('KC-Coinwash:removeWasher', tonumber(data.id))
    cb('ok')
end)

-- Push updated config to server
RegisterNUICallback('updateConfig', function(data, cb)
    TriggerServerEvent('KC-Coinwash:updateConfig', data)
    cb('ok')
end)

-- Teleport admin to a washer location
RegisterNUICallback('tpToWasher', function(data, cb)
    local c = data.coords
    if c then
        SetEntityCoords(PlayerPedId(), c.x, c.y, c.z + 0.5, false, false, false, false)
    end
    cb('ok')
end)

-- Close admin UI
RegisterNUICallback('closeAdmin', function(_, cb)
    adminUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)
