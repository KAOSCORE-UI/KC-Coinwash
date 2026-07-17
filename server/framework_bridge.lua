-- ╔══════════════════════════════════════════════╗
-- ║     SERVER FRAMEWORK BRIDGE                  ║
-- ╚══════════════════════════════════════════════╝

local SV = {}

-- ─── GET PLAYER OBJECT ───────────────────────────────────────────────────────
function SV.GetPlayer(src)
    if Config.Framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        return ESX.GetPlayerFromId(src)
    elseif Config.Framework == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.GetPlayer(src)
    end
    return nil
end

-- ─── CHECK DIRTY MONEY & REMOVE ──────────────────────────────────────────────
-- Returns the total dirty amount the player has (summing all dirty items)
function SV.GetDirtyAmount(src)
    local total = 0
    if Config.Inventory == 'ox_inventory' then
        for _, itemName in ipairs(Config.DirtyItems) do
            local count = exports.ox_inventory:GetItemCount(src, itemName)
            if count and count > 0 then total = total + count end
        end
    elseif Config.Inventory == 'qb-inventory' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        if player then
            for _, itemName in ipairs(Config.DirtyItems) do
                local item = player.Functions.GetItemByName(itemName)
                if item then total = total + item.amount end
            end
        end
    elseif Config.Inventory == 'esx_inventory' then
        local ESX = exports['es_extended']:getSharedObject()
        local player = ESX.GetPlayerFromId(src)
        if player then
            for _, itemName in ipairs(Config.DirtyItems) do
                local item = player.getInventoryItem(itemName)
                if item and item.count then total = total + item.count end
            end
        end
    end
    return total
end

-- Remove dirty money up to 'amount' across all dirty item types
function SV.RemoveDirty(src, amount)
    local remaining = amount
    if Config.Inventory == 'ox_inventory' then
        for _, itemName in ipairs(Config.DirtyItems) do
            if remaining <= 0 then break end
            local count = exports.ox_inventory:GetItemCount(src, itemName)
            if count and count > 0 then
                local toRemove = math.min(count, remaining)
                exports.ox_inventory:RemoveItem(src, itemName, toRemove)
                remaining = remaining - toRemove
            end
        end
    elseif Config.Inventory == 'qb-inventory' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        if player then
            for _, itemName in ipairs(Config.DirtyItems) do
                if remaining <= 0 then break end
                local item = player.Functions.GetItemByName(itemName)
                if item then
                    local toRemove = math.min(item.amount, remaining)
                    player.Functions.RemoveItem(itemName, toRemove)
                    remaining = remaining - toRemove
                end
            end
        end
    elseif Config.Inventory == 'esx_inventory' then
        local ESX = exports['es_extended']:getSharedObject()
        local player = ESX.GetPlayerFromId(src)
        if player then
            for _, itemName in ipairs(Config.DirtyItems) do
                if remaining <= 0 then break end
                local item = player.getInventoryItem(itemName)
                if item and item.count > 0 then
                    local toRemove = math.min(item.count, remaining)
                    player.removeInventoryItem(itemName, toRemove)
                    remaining = remaining - toRemove
                end
            end
        end
    end
    return remaining == 0
end

-- ─── PAY CLEAN MONEY ─────────────────────────────────────────────────────────
function SV.PayClean(src, amount)
    if Config.PayoutMethod == 'item' and Config.CleanItem then
        if Config.Inventory == 'ox_inventory' then
            exports.ox_inventory:AddItem(src, Config.CleanItem, amount)
        elseif Config.Inventory == 'qb-inventory' then
            local QBCore = exports['qb-core']:GetCoreObject()
            local player = QBCore.Functions.GetPlayer(src)
            if player then player.Functions.AddItem(Config.CleanItem, amount) end
        elseif Config.Inventory == 'esx_inventory' then
            local ESX = exports['es_extended']:getSharedObject()
            local player = ESX.GetPlayerFromId(src)
            if player then player.addInventoryItem(Config.CleanItem, amount) end
        end
    elseif Config.PayoutMethod == 'bank' then
        if Config.Framework == 'esx' then
            local ESX = exports['es_extended']:getSharedObject()
            local player = ESX.GetPlayerFromId(src)
            if player then player.addAccountMoney('bank', amount) end
        elseif Config.Framework == 'qbcore' then
            local QBCore = exports['qb-core']:GetCoreObject()
            local player = QBCore.Functions.GetPlayer(src)
            if player then player.Functions.AddMoney('bank', amount) end
        end
    else -- cash
        if Config.Framework == 'esx' then
            local ESX = exports['es_extended']:getSharedObject()
            local player = ESX.GetPlayerFromId(src)
            if player then player.addMoney(amount) end
        elseif Config.Framework == 'qbcore' then
            local QBCore = exports['qb-core']:GetCoreObject()
            local player = QBCore.Functions.GetPlayer(src)
            if player then player.Functions.AddMoney('cash', amount) end
        end
    end
end

-- ─── ADMIN CHECK ─────────────────────────────────────────────────────────────
function SV.IsAdmin(src)
    if Config.AdminCheck == 'ace' then
        return IsPlayerAceAllowed(src, Config.AdminAceNode)
    elseif Config.AdminCheck == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        local player = ESX.GetPlayerFromId(src)
        return player and player.getJob().name == Config.AdminESXJob
    elseif Config.AdminCheck == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local player = QBCore.Functions.GetPlayer(src)
        return player and player.PlayerData.job.name == Config.AdminQBJob
    end
    return false
end

-- ─── NOTIFY ──────────────────────────────────────────────────────────────────
function SV.Notify(src, msg, notifType)
    -- notifType: 'success' | 'error' | 'info' | 'warning'
    TriggerClientEvent('KC-Coinwash:notify', src, msg, notifType)
end

return SV
