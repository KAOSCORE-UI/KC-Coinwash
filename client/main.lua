-- ╔══════════════════════════════════════════════╗
-- ║         KC-COINWASH - CLIENT MAIN              ║
-- ╚══════════════════════════════════════════════╝

local washers       = {}      -- synced from server
local spawnedProps  = {}      -- { [washerId] = propHandle }
local isAdmin       = false
local nearbyWasher  = nil     -- washer table player is close to
local isWashing     = false
local washData      = nil

-- ─── UTILITIES ───────────────────────────────────────────────────────────────
local function Notify(msg, nType)
    nType = nType or 'info'
    if Config.NotifyStyle == 'ox_lib' then
        lib.notify({ title = 'Laundromat', description = msg, type = nType })
    elseif Config.NotifyStyle == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        ESX.ShowNotification(msg)
    elseif Config.NotifyStyle == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()
        QBCore.Functions.Notify(msg, nType)
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(msg)
        DrawNotification(false, true)
    end
end

-- ─── PROP MANAGEMENT ─────────────────────────────────────────────────────────
local function SpawnWasherProp(washer)
    if spawnedProps[washer.id] then return end

    local model = GetHashKey(Config.WasherProp)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    if not HasModelLoaded(model) then
        print('[KC-Coinwash] Failed to load prop model: ' .. Config.WasherProp)
        return
    end

    local c = washer.coords
    local prop = CreateObject(
        model,
        c.x, c.y, c.z + Config.PropZOffset,
        false, false, false
    )
    SetEntityHeading(prop, washer.heading or 0.0)
    FreezeEntityPosition(prop, true)
    SetEntityInvincible(prop, true)
    SetEntityCollision(prop, true, true)

    spawnedProps[washer.id] = prop
    SetModelAsNoLongerNeeded(model)
end

local function RemoveWasherProp(washerId)
    if spawnedProps[washerId] then
        DeleteObject(spawnedProps[washerId])
        spawnedProps[washerId] = nil
    end
end

local function RemoveAllProps()
    for id, _ in pairs(spawnedProps) do
        RemoveWasherProp(id)
    end
end

-- ─── SYNC WASHERS FROM SERVER ─────────────────────────────────────────────────
RegisterNetEvent('KC-Coinwash:syncWashers', function(newWashers)
    -- Remove props that no longer exist
    local newIds = {}
    for _, w in ipairs(newWashers) do newIds[w.id] = true end
    for id, _ in pairs(spawnedProps) do
        if not newIds[id] then RemoveWasherProp(id) end
    end

    washers = newWashers

    -- Spawn props for all washers
    for _, w in ipairs(washers) do
        SpawnWasherProp(w)
    end
end)

RegisterNetEvent('KC-Coinwash:setAdmin', function(adminStatus)
    isAdmin = adminStatus
end)

-- ─── REQUEST SYNC ON SPAWN ────────────────────────────────────────────────────
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then
        Wait(1000)
        TriggerServerEvent('KC-Coinwash:requestSync')
    end
end)

-- ─── THIRD EYE / INTERACTION DETECTION ───────────────────────────────────────
-- Uses ox_lib target if available, otherwise falls back to distance loop + E key

local useTarget = pcall(function() return exports.ox_target end)

local function RegisterThirdEye()
    if useTarget then
        -- ox_target approach: register each prop as it spawns
        -- handled in SpawnWasherProp via exports.ox_target:addLocalEntity
    else
        -- Fallback: proximity loop (see thread below)
    end
end

-- We use a manual loop that works with any setup
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        nearbyWasher = nil
        for _, w in ipairs(washers) do
            local wc = w.coords
            local dist = #(playerCoords - vector3(wc.x, wc.y, wc.z))
            if dist < Config.InteractDistance + 3.0 then
                sleep = 0
                if dist < Config.InteractDistance then
                    nearbyWasher = w
                    break
                end
            end
        end

        Wait(sleep)
    end
end)

-- Draw 3D text and handle E press
CreateThread(function()
    while true do
        if nearbyWasher and not isWashing then
            local c = nearbyWasher.coords
            -- Draw text above prop
            local onScreen, sx, sy = World3dToScreen2d(c.x, c.y, c.z + 1.2)
            if onScreen then
                SetTextScale(0.0, 0.45)
                SetTextFont(4)
                SetTextProportional(true)
                SetTextColour(0, 255, 136, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentString('[E] Launder Money')
                EndTextCommandDisplayText(sx, sy)

                -- Sub label
                SetTextScale(0.0, 0.30)
                SetTextFont(4)
                SetTextProportional(true)
                SetTextColour(180, 180, 180, 200)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentString(nearbyWasher.label or 'Washing Machine')
                EndTextCommandDisplayText(sx, sy + 0.035)
            end

            -- E to interact
            if IsControlJustPressed(0, 38) then -- E key
                OpenWashUI(nearbyWasher)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ─── OPEN WASH UI ─────────────────────────────────────────────────────────────
function OpenWashUI(washer)
    if isWashing then return end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action  = 'openWash',
        washer  = washer,
        config  = {
            washFee      = Config.WashFee,
            washDuration = Config.WashDuration,
            maxWash      = Config.MaxWash,
            minWash      = Config.MinWash,
            riskLevel    = Config.DefaultRiskLevel,
            payMethod    = Config.PayoutMethod,
        },
    })
end

-- ─── NUI CALLBACKS ───────────────────────────────────────────────────────────
RegisterNUICallback('closeWash', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('startWash', function(data, cb)
    local washerId  = tonumber(data.washerId)
    local amount    = tonumber(data.amount)
    local riskLevel = tonumber(data.riskLevel) or 1
    TriggerServerEvent('KC-Coinwash:startWash', washerId, amount, riskLevel)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('cancelWash', function(_, cb)
    TriggerServerEvent('KC-Coinwash:cancelWash')
    cb('ok')
end)

-- ─── WASH EVENTS FROM SERVER ──────────────────────────────────────────────────
RegisterNetEvent('KC-Coinwash:washStarted', function(data)
    isWashing = true
    washData  = data
    -- Show progress overlay
    SendNUIMessage({ action = 'washStarted', data = data })
    SetNuiFocus(false, false)

    -- Play washer animation on nearby prop
    local prop = nearbyWasher and spawnedProps[nearbyWasher.id]
    if prop then
        -- shake prop slightly to imply it's running
        -- (full anim would require a scenario - this keeps it framework-agnostic)
    end

    -- Task player to stand there
    local ped = PlayerPedId()
    TaskStandStill(ped, data.duration * 1000)
end)

RegisterNetEvent('KC-Coinwash:washComplete', function(cleanAmt)
    isWashing = false
    washData  = nil
    ClearPedTasks(PlayerPedId())
    SendNUIMessage({ action = 'washComplete', cleanAmt = cleanAmt })
    Wait(3000)
    SendNUIMessage({ action = 'hideOverlay' })
end)

RegisterNetEvent('KC-Coinwash:washCancelled', function()
    isWashing = false
    washData  = nil
    ClearPedTasks(PlayerPedId())
    SendNUIMessage({ action = 'hideOverlay' })
end)

RegisterNetEvent('KC-Coinwash:configUpdate', function(cfg)
    Config.WashFee         = cfg.washFee      or Config.WashFee
    Config.WashDuration    = cfg.washDuration  or Config.WashDuration
    Config.MaxWash         = cfg.maxWash       or Config.MaxWash
    Config.DefaultRiskLevel= cfg.riskLevel     or Config.DefaultRiskLevel
end)

RegisterNetEvent('KC-Coinwash:notify', function(msg, nType)
    Notify(msg, nType)
end)

-- ─── RESOURCE STOP CLEANUP ────────────────────────────────────────────────────
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        RemoveAllProps()
        SetNuiFocus(false, false)
    end
end)
