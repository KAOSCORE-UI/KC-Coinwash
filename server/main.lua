-- ╔══════════════════════════════════════════════╗
-- ║         KC-COINWASH - SERVER MAIN              ║
-- ╚══════════════════════════════════════════════╝

local SV            = nil
-- Re-load bridge inline since exports aren't self-accessible
local bridge        = load(LoadResourceFile(GetCurrentResourceName(), 'server/framework_bridge.lua'))()

local washers       = {}       -- { id, coords={x,y,z}, heading, label }
local cooldowns     = {}       -- [src] = timestamp
local activeWashes  = {}       -- [src] = true while washing
local nextId        = 1

-- ─── PERSISTENCE ─────────────────────────────────────────────────────────────
local saveFile = GetResourcePath(GetCurrentResourceName()) .. '/' .. Config.SaveFile

local function LoadWashers()
    if not Config.PersistLocations then return end
    local data = LoadResourceFile(GetCurrentResourceName(), Config.SaveFile)
    if data and data ~= '' then
        local decoded = json.decode(data)
        if decoded then
            washers = decoded
            -- find max id
            for _, w in ipairs(washers) do
                if w.id >= nextId then nextId = w.id + 1 end
            end
            print('[KC-Coinwash] Loaded ' .. #washers .. ' washer locations.')
        end
    end
end

local function SaveWashers()
    if not Config.PersistLocations then return end
    SaveResourceFile(GetCurrentResourceName(), Config.SaveFile, json.encode(washers), -1)
end

-- ─── SEND WASHERS TO CLIENT ───────────────────────────────────────────────────
local function SyncWashers(target)
    if target then
        TriggerClientEvent('KC-Coinwash:syncWashers', target, washers)
    else
        TriggerClientEvent('KC-Coinwash:syncWashers', -1, washers)
    end
end

-- ─── PLAYER CONNECT ──────────────────────────────────────────────────────────
AddEventHandler('playerConnecting', function()
    -- handled by spawn event below
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        LoadWashers()
        Wait(2000)
        SyncWashers(-1)
    end
end)

-- Sync when player spawns
AddEventHandler('playerSpawned', function()
    -- some frameworks trigger this
end)

RegisterNetEvent('KC-Coinwash:requestSync', function()
    local src = source
    SyncWashers(src)
    -- also tell client if they are admin
    TriggerClientEvent('KC-Coinwash:setAdmin', src, bridge.IsAdmin(src))
end)

-- ─── ADMIN: PLACE WASHER ─────────────────────────────────────────────────────
RegisterNetEvent('KC-Coinwash:placeWasher', function(coords, heading, label)
    local src = source
    if not bridge.IsAdmin(src) then
        bridge.Notify(src, 'No permission.', 'error')
        return
    end
    local w = {
        id      = nextId,
        coords  = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading or 0.0,
        label   = label or ('Washer #' .. nextId),
    }
    nextId = nextId + 1
    table.insert(washers, w)
    SaveWashers()
    SyncWashers(-1)
    bridge.Notify(src, 'Washer placed: ' .. w.label, 'success')
end)

-- ─── ADMIN: REMOVE WASHER ─────────────────────────────────────────────────────
RegisterNetEvent('KC-Coinwash:removeWasher', function(washerId)
    local src = source
    if not bridge.IsAdmin(src) then
        bridge.Notify(src, 'No permission.', 'error')
        return
    end
    for i, w in ipairs(washers) do
        if w.id == washerId then
            table.remove(washers, i)
            SaveWashers()
            SyncWashers(-1)
            bridge.Notify(src, 'Washer removed.', 'success')
            return
        end
    end
    bridge.Notify(src, 'Washer not found.', 'error')
end)

-- ─── ADMIN: UPDATE WASHER CONFIG ─────────────────────────────────────────────
RegisterNetEvent('KC-Coinwash:updateConfig', function(newConfig)
    local src = source
    if not bridge.IsAdmin(src) then return end
    -- Validate and clamp
    if newConfig.washFee then
        Config.WashFee = math.max(1, math.min(60, tonumber(newConfig.washFee) or Config.WashFee))
    end
    if newConfig.washDuration then
        Config.WashDuration = math.max(5, math.min(300, tonumber(newConfig.washDuration) or Config.WashDuration))
    end
    if newConfig.maxWash then
        Config.MaxWash = math.max(100, tonumber(newConfig.maxWash) or Config.MaxWash)
    end
    if newConfig.riskLevel then
        Config.DefaultRiskLevel = math.max(1, math.min(3, tonumber(newConfig.riskLevel) or 1))
    end
    -- Broadcast updated config to all clients
    TriggerClientEvent('KC-Coinwash:configUpdate', -1, {
        washFee      = Config.WashFee,
        washDuration = Config.WashDuration,
        maxWash      = Config.MaxWash,
        riskLevel    = Config.DefaultRiskLevel,
    })
    bridge.Notify(src, 'Config updated.', 'success')
end)

-- ─── PLAYER: START WASH ──────────────────────────────────────────────────────
RegisterNetEvent('KC-Coinwash:startWash', function(washerId, amount, riskLevel)
    local src = source

    -- Cooldown check
    if cooldowns[src] and (GetGameTimer() - cooldowns[src]) < (Config.PlayerCooldown * 1000) then
        local remaining = math.ceil(Config.PlayerCooldown - (GetGameTimer() - cooldowns[src]) / 1000)
        bridge.Notify(src, 'Washer cooling down. Wait ' .. remaining .. 's.', 'warning')
        return
    end

    -- Already washing?
    if activeWashes[src] then
        bridge.Notify(src, 'Already washing!', 'warning')
        return
    end

    -- Validate washer exists
    local washerExists = false
    for _, w in ipairs(washers) do
        if w.id == washerId then washerExists = true break end
    end
    if not washerExists then
        bridge.Notify(src, 'Invalid washer.', 'error')
        return
    end

    -- Clamp amount
    amount = math.max(Config.MinWash, math.min(Config.MaxWash, math.floor(tonumber(amount) or 0)))
    if amount <= 0 then
        bridge.Notify(src, 'Invalid amount.', 'error')
        return
    end

    -- Check dirty money
    local dirtyAmount = bridge.GetDirtyAmount(src)
    if dirtyAmount < amount then
        bridge.Notify(src,
            'Not enough dirty money. You have $' .. dirtyAmount .. ', need $' .. amount,
            'error')
        return
    end

    -- Calculate clean payout
    riskLevel = math.max(1, math.min(3, tonumber(riskLevel) or 1))
    local feePct   = Config.WashFee
    local riskPct  = Config.RiskDeduction[riskLevel] or 0
    local totalPct = feePct + riskPct
    local cleanAmt = math.floor(amount * (1 - totalPct / 100))

    -- Remove dirty money immediately
    local removed = bridge.RemoveDirty(src, amount)
    if not removed then
        bridge.Notify(src, 'Failed to remove dirty money.', 'error')
        return
    end

    -- Mark as washing
    activeWashes[src] = true
    cooldowns[src]    = GetGameTimer()

    -- Tell client to start animation / progress bar
    TriggerClientEvent('KC-Coinwash:washStarted', src, {
        amount      = amount,
        cleanAmt    = cleanAmt,
        duration    = Config.WashDuration,
        feePct      = feePct,
        riskPct     = riskPct,
    })

    -- Wait wash duration then pay out
    SetTimeout(Config.WashDuration * 1000, function()
        if activeWashes[src] then
            activeWashes[src] = nil
            bridge.PayClean(src, cleanAmt)
            bridge.Notify(src,
                'Wash complete! Received $' .. cleanAmt .. ' clean ' ..
                (Config.PayoutMethod == 'bank' and '(bank)' or '(cash)'),
                'success')
            TriggerClientEvent('KC-Coinwash:washComplete', src, cleanAmt)
        end
    end)
end)

-- ─── PLAYER: CANCEL WASH ─────────────────────────────────────────────────────
RegisterNetEvent('KC-Coinwash:cancelWash', function()
    local src = source
    -- Note: money was already taken; cancellation forfeits it (punishes exploitation)
    if activeWashes[src] then
        activeWashes[src] = nil
        bridge.Notify(src, 'Wash cancelled. Money forfeited.', 'warning')
        TriggerClientEvent('KC-Coinwash:washCancelled', src)
    end
end)

-- ─── CLEANUP ON DROP ─────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    activeWashes[src] = nil
    cooldowns[src]    = nil
end)

-- ─── ADMIN: GET WASHER LIST (NUI) ────────────────────────────────────────────
RegisterNetEvent('KC-Coinwash:adminGetWashers', function()
    local src = source
    if not bridge.IsAdmin(src) then 
        bridge.Notify(src, 'You do not have permission to use this command.', 'error')
        return 
    end
    TriggerClientEvent('KC-Coinwash:adminWasherList', src, washers)
end)
