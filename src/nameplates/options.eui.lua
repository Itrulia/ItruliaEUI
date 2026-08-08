local addonName, ItruliaEUI = ...

local moduleName = "Nameplates"
local Nameplates = ItruliaEUI:GetModule(moduleName)

function Nameplates:GetEUIOptions()
    return {
        name = "Nameplates",
        rows = {
            {
                type = "toggle",
                label = "Treat casts targeted at player as important",
                tooltip = "Glows the cast bar of any cast aimed at you, using the look of the nameplates' own important-cast glow.",
                disabled = function()
                    return not Nameplates.db.enabled
                end,
                disabledTooltip = "Nameplates",
                get = function()
                    return Nameplates.db.importantWhenTargeted
                end,
                set = function(value)
                    Nameplates.db.importantWhenTargeted = value
                    Nameplates:RefreshConfig()
                end,
            },
        },
    }
end
