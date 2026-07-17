-- ╔══════════════════════════════════════════════╗
-- ║     FRAMEWORK BRIDGE - SHARED STUBS          ║
-- ╚══════════════════════════════════════════════╝
-- Extend this file to support additional frameworks.
-- Server-side bridge is in server/framework_bridge.lua

Bridge = {}

-- Called client-side to get player data (used for notify style etc.)
function Bridge.IsClient()
    return IsDuplicityVersion() == false
end
