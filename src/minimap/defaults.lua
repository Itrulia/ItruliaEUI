local addonName, ItruliaEUI = ...

local moduleName = "Minimap"
local MinimapModule = ItruliaEUI:GetModule(moduleName)

function MinimapModule:GetDefaults()
    return {
        enabled = true,
        rightClickTracking = true,
    }
end
