Config = {}

-- ╔══════════════════════════════════════════════╗
-- ║         KC-COINWASH - CONFIGURATION            ║
-- ╚══════════════════════════════════════════════╝

-- Framework: 'esx' | 'qbcore' | 'custom'
Config.Framework = 'qbcore'

-- Inventory: 'ox_inventory' | 'qb-inventory' | 'esx_inventory' | 'custom'
Config.Inventory = 'ox_inventory'

-- Admin permission check: 'ace' | 'esx' | 'qbcore' | 'custom'
-- ace = uses FiveM ACE permissions (add_ace group.admin KC-Coinwash.admin allow)
Config.AdminCheck = 'ace'
Config.AdminAceNode = 'KC-Coinwash.admin'
Config.AdminESXJob = 'police'   -- if AdminCheck = 'esx', job name
Config.AdminQBJob  = 'police'   -- if AdminCheck = 'qbcore'

-- Dirty money item names (all treated as dirty input)
Config.DirtyItems = {
    'black_money',
    'dirty_money',
    'dirtymoney',
    'blackmoney',
}

-- Output item when washing (set to nil to pay cash/bank instead of item)
Config.CleanItem = nil  -- e.g. 'money' or nil for account payment

-- Where clean money goes: 'cash' | 'bank' | 'item'
Config.PayoutMethod = 'cash'  -- 'cash' gives on-hand cash, 'bank' deposits

-- Wash fee percentage taken (server-side truth)
Config.WashFee = 15  -- 15% fee

-- Risk deductions per risk level
Config.RiskDeduction = {
    [1] = 0,   -- low
    [2] = 3,   -- medium
    [3] = 8,   -- high
}

-- Min/max per single wash
Config.MinWash = 100
Config.MaxWash = 50000

-- Wash duration in seconds (server-side)
Config.WashDuration = 30

-- Cooldown between washes per player (seconds)
Config.PlayerCooldown = 60

-- Third-eye / interaction distance (metres)
Config.InteractDistance = 1.5

-- Prop to spawn for washing machines
Config.WasherProp = 'prop_washer_01'

-- Z-offset so prop sits on floor correctly
Config.PropZOffset = -1.0

-- NUI key to close admin tablet
Config.CloseKey = 'Escape'

-- Saved washer locations persist to file (true) or only until resource restart (false)
Config.PersistLocations = true
Config.SaveFile = 'washer_locations.json'

-- Default risk level shown on player UI
Config.DefaultRiskLevel = 1

-- Notify style: 'ox_lib' | 'esx' | 'qbcore' | 'custom'
Config.NotifyStyle = 'ox_lib'
