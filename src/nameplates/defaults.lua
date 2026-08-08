local addonName, ItruliaEUI = ...

local moduleName = "Nameplates"
local Nameplates = ItruliaEUI:GetModule(moduleName)

function Nameplates:GetDefaults()
    return {
        enabled = true,
        importantWhenTargeted = true,
    }
end
