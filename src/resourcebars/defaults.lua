local addonName, ItruliaEUI = ...

local moduleName = "ResourceBars"
local ResourceBars = ItruliaEUI:GetModule(moduleName)

function ResourceBars:GetDefaults()
    return {
        enabled = true,
        textures = {},
        split = {},
    }
end
