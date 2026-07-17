-- ╔══════════════════════════════════════════════╗
-- ║         KC-COINWASH - CLIENT NUI BRIDGE        ║
-- ╚══════════════════════════════════════════════╝
-- Handles NUI focus escape key

CreateThread(function()
    while true do
        Wait(0)
        if IsNuiFocused() and IsControlJustPressed(0, 200) then -- Escape
            SendNUIMessage({ action = 'escape' })
            SetNuiFocus(false, false)
        end
    end
end)
