local addonName, ItruliaEUI = ...
local moduleName = "Nameplates"

local Nameplates = ItruliaEUI:NewModule(moduleName)
Nameplates.euiDisplay = "Nameplates"
Nameplates.euiDescription = "Additions to EllesmereUI's nameplates."

local ns = _G.EllesmereNameplates_NS

local function getPlate(unit)
    local plates = ns and ns.plates

    return plates and plates[unit]
end

local function glowSettings()
    if not ns then
        return nil
    end

    local defaults = ns.defaults or {}
    local cfg = (ns.db and ns.db.profile) or defaults

    local style = cfg.importantCastGlowStyle or defaults.importantCastGlowStyle or 1

    -- The two styles EllesmereUI's own glow accepts, and no others.
    if style ~= 1 and style ~= 4 then
        style = 1
    end

    return {
        style = style,
        color = cfg.importantCastGlowColor or defaults.importantCastGlowColor or { r = 1, g = 0.2, b = 0.2 },
        bgColor = cfg.importantCastGlowBackgroundColor or defaults.importantCastGlowBackgroundColor or { r = 0, g = 0, b = 0 },
        bgOn = cfg.importantCastGlowBackground == true,
        lines = cfg.importantCastGlowLines or defaults.importantCastGlowLines or 8,
        thickness = cfg.importantCastGlowThickness or defaults.importantCastGlowThickness or 2,
        period = cfg.importantCastGlowSpeed or defaults.importantCastGlowSpeed or 4,
    }
end

local function stopGlow(plate)
    local overlay = plate._itruliaTargetOverlay

    if not (overlay and plate._itruliaTargetGlowActive) then
        return
    end

    local Glows = EllesmereUI and EllesmereUI.Glows

    if Glows then
        Glows.StopAllGlows(overlay)
    end

    overlay:SetAlpha(0)
    overlay:Hide()

    plate._itruliaTargetGlowActive = false
    plate._itruliaTargetGlowStyle = nil
end

local function ensureGlow(plate, s)
    local Glows = EllesmereUI and EllesmereUI.Glows

    if not Glows then
        return false
    end

    local overlay = plate._itruliaTargetOverlay

    if not overlay then
        overlay = CreateFrame("Frame", nil, plate.cast)
        overlay:SetAllPoints(plate.cast)
        overlay:SetFrameLevel(plate.cast:GetFrameLevel() + 5)
        overlay:EnableMouse(false)
        plate._itruliaTargetOverlay = overlay
    end

    local c, bg = s.color, s.bgColor

    if plate._itruliaTargetGlowActive
        and plate._itruliaTargetGlowStyle == s.style
        and plate._itruliaTargetGlowR == c.r and plate._itruliaTargetGlowG == c.g and plate._itruliaTargetGlowB == c.b
        and plate._itruliaTargetGlowBgOn == s.bgOn
        and plate._itruliaTargetGlowBgR == bg.r and plate._itruliaTargetGlowBgG == bg.g and plate._itruliaTargetGlowBgB == bg.b
        and plate._itruliaTargetGlowN == s.lines
        and plate._itruliaTargetGlowTh == s.thickness
        and plate._itruliaTargetGlowPeriod == s.period then
        return true
    end

    Glows.StopAllGlows(overlay)

    local w, h = plate.cast:GetWidth(), plate.cast:GetHeight()

    if w < 5 then
        w = 100
    end

    if h < 5 then
        h = 14
    end

    if s.style == 4 then
        Glows.StartAutoCastShine(overlay, w, c.r, c.g, c.b, 1.0, h)
    else
        local lineLen = math.floor((w + h) * (2 / s.lines - 0.1))
        lineLen = math.min(lineLen, math.min(w, h))

        if lineLen < 1 then
            lineLen = 1
        end

        Glows.StartProceduralAnts(overlay, s.lines, s.thickness, s.period, lineLen,
            c.r, c.g, c.b, w, h,
            s.bgOn and (bg.r or 0) or nil, bg.g or 0, bg.b or 0)
    end

    plate._itruliaTargetGlowActive = true
    plate._itruliaTargetGlowStyle = s.style
    plate._itruliaTargetGlowR, plate._itruliaTargetGlowG, plate._itruliaTargetGlowB = c.r, c.g, c.b
    plate._itruliaTargetGlowBgOn = s.bgOn
    plate._itruliaTargetGlowBgR, plate._itruliaTargetGlowBgG, plate._itruliaTargetGlowBgB = bg.r, bg.g, bg.b
    plate._itruliaTargetGlowN = s.lines
    plate._itruliaTargetGlowTh = s.thickness
    plate._itruliaTargetGlowPeriod = s.period

    return true
end

local function updateTargetGlow(plate)
    if not (Nameplates.db.enabled and Nameplates.db.importantWhenTargeted) then
        stopGlow(plate)

        return
    end

    local unit = plate.unit

    if not (unit and plate.cast and PlayerIsSpellTarget) then
        stopGlow(plate)

        return
    end

    if not plate.cast:IsShown() then
        stopGlow(plate)

        return
    end

    local ok, targeted = pcall(PlayerIsSpellTarget, unit)

    if not ok then
        stopGlow(plate)

        return
    end

    local s = glowSettings()

    if not (s and ensureGlow(plate, s)) then
        return
    end

    plate._itruliaTargetOverlay:Show()
    plate._itruliaTargetOverlay:SetAlphaFromBoolean(targeted)
end

local function hookIntoPlate(plate)
    if not plate or plate._itruliaEUITargetGlowHook then
        return
    end

    local updateCast = plate.UpdateCast

    if type(updateCast) ~= "function" then
        return
    end

    plate._itruliaEUITargetGlowHook = true

    updateTargetGlow(plate)
    plate.UpdateCast = function(self, ...)
        local result = updateCast(self, ...)

        updateTargetGlow(self)

        return result
    end
end

local function OnEvent(_, _, unit)
    local plate = getPlate(unit)

    if plate then
        hookIntoPlate(plate)
    end
end

function Nameplates:LoadDB()
    local profile = ItruliaEUI.db.profile
    profile[moduleName] = profile[moduleName] or self:GetDefaults()

    return profile[moduleName]
end

function Nameplates:OnInitialize()
    self.db = self:LoadDB()
end

function Nameplates:StopAllGlows()
    for _, plate in pairs((ns and ns.plates) or {}) do
        stopGlow(plate)
    end
end

function Nameplates:RefreshConfig()
    self.db = self:LoadDB()

    if not self.db.enabled then
        if self.frame then
            self.frame:UnregisterAllEvents()
        end

        self:StopAllGlows()

        return
    end

    if not ns then
        return
    end

    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", OnEvent)
    self.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self.frame:RegisterEvent("UNIT_SPELLCAST_START")
    self.frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self.frame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    self.frame:RegisterEvent("UNIT_TARGET")

    -- Plates that were already up when the module was switched on.
    for unit in pairs(ns.plates or {}) do
        hookIntoPlate(getPlate(unit))
    end

    if not self.db.importantWhenTargeted then
        self:StopAllGlows()
    end
end

function Nameplates:OnEnable()
    self:RefreshConfig()
end
