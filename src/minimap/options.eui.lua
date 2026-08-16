local addonName, ItruliaEUI = ...

local moduleName = "Minimap"
local MinimapModule = ItruliaEUI:GetModule(moduleName)

function MinimapModule:GetEUIOptions()
    return {
        name = "Minimap",
        rows = {
            {
                type = "toggle",
                label = "Right click opens the tracking menu",
                tooltip = "Opens the tracking menu at the cursor when you right click the minimap, so tracking stays reachable with EllesmereUI's tracking button hidden. The right click no longer pings the map.",
                disabled = function()
                    return not MinimapModule.db.enabled
                end,
                disabledTooltip = "Minimap",
                get = function()
                    return MinimapModule.db.rightClickTracking
                end,
                set = function(value)
                    MinimapModule.db.rightClickTracking = value
                    MinimapModule:RefreshConfig()
                end,
            },
        },
    }
end
