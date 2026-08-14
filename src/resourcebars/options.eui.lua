local addonName, ItruliaEUI = ...

local moduleName = "ResourceBars"
local ResourceBars = ItruliaEUI:GetModule(moduleName)

-- One statusbar dropdown per power type, two to a row, split into the resources
-- EllesmereUI draws as the primary bar and the ones it draws as the class bar.
-- Built from the module's own POWER_TYPES list rather than a second list here, so
-- adding a power type there gives it a row without touching this file.
--
-- The dropdown is ItruliaQoL's statusbar picker (EUIStatusbarRow), the one that
-- labels each entry with the texture's name and previews the texture behind it,
-- rather than a select over raw file paths.
local function textureRow(power)
    local row = ItruliaEUI.QoL:EUIStatusbarRow({
        label = power.label,
        disabled = function()
            return not ResourceBars.db.enabled
        end,
        get = function()
            return ResourceBars.db.textures[power.key]
        end,
        set = function(value)
            ResourceBars.db.textures[power.key] = value
            ResourceBars:ApplyTextures()
        end,
    })

    -- Set after the fact: EUIStatusbarRow forwards `disabled` but not the tooltip
    -- explaining it, and without one a greyed-out dropdown says nothing about why.
    row.disabledTooltip = "Resource Bars"

    -- A class resource's "Split" lives on its dropdown's cogwheel rather than on a
    -- row of its own: seven more toggles would double the length of this page, and
    -- a setting about how one resource is drawn belongs next to that resource's
    -- other setting. Only the class resources get one -- the primary bar is a
    -- single bar with nothing to split.
    if power.class then
        row.cog = {
            title = power.label,
            rows = {
                {
                    type = "toggle",
                    label = "Split into separate bars",
                    tooltip = "Draws each " .. power.label:lower()
                        .. " as its own bar, with the background and border moved from the whole class resource bar onto each one. Uses the class resource's own background and border settings.",
                    get = function()
                        return ResourceBars.db.split[power.key]
                    end,
                    set = function(value)
                        ResourceBars.db.split[power.key] = value or nil

                        -- Through EllesmereUI's own rebuild rather than straight to
                        -- ApplyTextures: it repositions and re-styles the pips from
                        -- scratch, which is what makes turning this off land the
                        -- container's border and background back where they were.
                        -- Our own re-apply follows it, off the ApplyAll hook.
                        local ERB = EllesmereUI and EllesmereUI.Lite
                            and EllesmereUI.Lite.GetAddon("EllesmereUIResourceBars", true)

                        if ERB and ERB.ApplyAll then
                            ERB:ApplyAll()
                        else
                            ResourceBars:ApplyTextures()
                        end
                    end,
                },
            },
        }
    end

    return row
end

local function paired(rows, out)
    for i = 1, #rows, 2 do
        out[#out + 1] = { pair = { rows[i], rows[i + 1] or { type = "empty" } } }
    end
end

function ResourceBars:GetEUIOptions()
    local primary, class = {}, {}

    for _, power in ipairs(self.PowerTypes) do
        local target = power.class and class or primary

        target[#target + 1] = textureRow(power)
    end

    local rows = {
        {
            text = "Each power type can have its own bar texture. EllesmereUI's own Bar Texture setting keeps every bar it draws in step; these override it per resource, following whatever your current spec and form are showing.",
        },
        { header = "PRIMARY RESOURCE" },
    }

    paired(primary, rows)

    rows[#rows + 1] = { spacer = 8 }
    rows[#rows + 1] = { header = "CLASS RESOURCE" }
    rows[#rows + 1] = {
        text = "Used for the class bar, the pips, runes or bar EllesmereUI draws for your secondary resource. The cogwheel next to each one splits it into separate bars, one per point, instead of pips sharing a single frame.",
    }

    paired(class, rows)

    rows[#rows + 1] = { spacer = 12 }
    rows[#rows + 1] = {
        type = "execute",
        label = "Clear All Textures",
        -- The only way back to "unset": the dropdowns list the textures
        -- LibSharedMedia knows about and have no entry standing for "leave this
        -- one to EllesmereUI", so clearing is a button rather than a menu item.
        func = function()
            ResourceBars.db.textures = {}

            local ERB = EllesmereUI and EllesmereUI.Lite
                and EllesmereUI.Lite.GetAddon("EllesmereUIResourceBars", true)

            -- Repaint from EllesmereUI's own setting; ApplyTextures alone would
            -- leave the textures we already painted on screen.
            if ERB and ERB.ApplyAll then
                ERB:ApplyAll()
            end
        end,
        disabled = function()
            return not ResourceBars.db.enabled
        end,
        disabledTooltip = "Resource Bars",
        refresh = true,
    }

    return {
        name = "Resource Bars",
        rows = rows,
    }
end
