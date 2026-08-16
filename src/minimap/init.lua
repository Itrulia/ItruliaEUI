local addonName, ItruliaEUI = ...
local moduleName = "Minimap"

local MinimapModule = ItruliaEUI:NewModule(moduleName)
MinimapModule.euiDisplay = "Minimap"
MinimapModule.euiDescription = "Additions to EllesmereUI's minimap."

local function trackingButton()
    local tracking = MinimapCluster and MinimapCluster.Tracking

    return tracking and tracking.Button
end

local function isMenuOpen(button)
    local menu = button.menu

    return (menu and menu:IsShown()) or false
end

local function closeMenu(button)
    if button.CloseMenu then
        button:CloseMenu()
    elseif button.menu then
        button.menu:Hide()
    end
end

-- EllesmereUI's own tracking indicator parks the hidden Blizzard button on itself
-- before opening, so the menu lands wherever that button currently sits. Right
-- clicking the map has no such anchor, so the menu is moved to the cursor after
-- the fact, the way any other context menu opens.
local function anchorToCursor(menu)
    if not menu then
        return
    end

    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()

    menu:SetClampedToScreen(true)
    menu:ClearAllPoints()
    PixelUtil.SetPoint(menu, "TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
end

local menuWasOpen = false

local function snapshotMenu()
    local button = trackingButton()

    -- The menu manager closes an open menu on the mouse down of any click outside
    -- it, so by the time the mouse up runs it is already gone. Without this
    -- snapshot the second right click would reopen it and it could never be
    -- dismissed by clicking the map again.
    menuWasOpen = (button and isMenuOpen(button)) or false
end

local function toggleTrackingMenu()
    local button = trackingButton()

    if not (button and button.OpenMenu) then
        return
    end

    if menuWasOpen then
        menuWasOpen = false
        closeMenu(button)

        return
    end

    if not isMenuOpen(button) then
        button:OpenMenu()
    end

    anchorToCursor(button.menu)
end

function MinimapModule:IsRightClickTrackingActive()
    return (self.db and self.db.enabled and self.db.rightClickTracking) or false
end

-- Scripted rather than overlaid: an overlay covering the map would have to sit
-- above EllesmereUI's middle-click blocker, which puts it above the tracking,
-- calendar and mail indicators it anchors inside the map as well, swallowing
-- their clicks.
--
-- Replaced rather than hooked, because the minimap's own handlers ping the clicked
-- spot and a hook runs too late to stop that. Both buttons are wrapped rather than
-- only the one that pings today, so which of the two Blizzard uses does not matter.
-- Anything but a right click, and every click at all while the setting is off, goes
-- straight to the original, so nothing needs unhooking when it is turned back off.
function MinimapModule:HookMinimap()
    if self.minimapHooked or not Minimap then
        return
    end

    self.minimapHooked = true

    local blizzardOnMouseDown = Minimap:GetScript("OnMouseDown")
    local blizzardOnMouseUp = Minimap:GetScript("OnMouseUp")

    Minimap:SetScript("OnMouseDown", function(frame, mouseButton, ...)
        if mouseButton == "RightButton" and MinimapModule:IsRightClickTrackingActive() then
            snapshotMenu()

            return
        end

        if blizzardOnMouseDown then
            blizzardOnMouseDown(frame, mouseButton, ...)
        end
    end)

    Minimap:SetScript("OnMouseUp", function(frame, mouseButton, ...)
        if mouseButton == "RightButton" and MinimapModule:IsRightClickTrackingActive() then
            toggleTrackingMenu()

            return
        end

        if blizzardOnMouseUp then
            blizzardOnMouseUp(frame, mouseButton, ...)
        end
    end)
end

function MinimapModule:LoadDB()
    local profile = ItruliaEUI.db.profile
    profile[moduleName] = profile[moduleName] or self:GetDefaults()

    return profile[moduleName]
end

function MinimapModule:OnInitialize()
    self.db = self:LoadDB()
end

function MinimapModule:RefreshConfig()
    self.db = self:LoadDB()

    if not self.db.enabled then
        return
    end

    self:HookMinimap()
end

function MinimapModule:OnEnable()
    self:RefreshConfig()
end
