local addonName, ItruliaEUI = ...
local moduleName = "ResourceBars"

local ResourceBars = ItruliaEUI:NewModule(moduleName)
ResourceBars.euiDisplay = "Resource Bars"
ResourceBars.euiDescription = "Give each power type its own statusbar texture on EllesmereUI's resource and class bars and allow splitting the individual resource items."

local PT = Enum and Enum.PowerType or {}

ResourceBars.PowerTypes = {
    { key = "MANA",           label = "Mana",           enum = PT.Mana or 0 },
    { key = "RAGE",           label = "Rage",           enum = PT.Rage or 1 },
    { key = "FOCUS",          label = "Focus",          enum = PT.Focus or 2 },
    { key = "ENERGY",         label = "Energy",         enum = PT.Energy or 3 },
    { key = "RUNIC_POWER",    label = "Runic Power",    enum = PT.RunicPower or 6 },
    { key = "LUNAR_POWER",    label = "Astral Power",   enum = PT.LunarPower or 8 },
    { key = "MAELSTROM",      label = "Maelstrom",      enum = PT.Maelstrom or 11 },
    { key = "INSANITY",       label = "Insanity",       enum = PT.Insanity or 13 },
    { key = "FURY",           label = "Fury",           enum = PT.Fury or 17 },
    { key = "PAIN",           label = "Pain",           enum = PT.Pain or 18 },
    { key = "COMBO_POINTS",   label = "Combo Points",   enum = PT.ComboPoints or 4,    class = true },
    { key = "RUNES",          label = "Runes",          enum = PT.Runes or 5,          class = true },
    { key = "SOUL_SHARDS",    label = "Soul Shards",    enum = PT.SoulShards or 7,     class = true },
    { key = "HOLY_POWER",     label = "Holy Power",     enum = PT.HolyPower or 9,      class = true },
    { key = "CHI",            label = "Chi",            enum = PT.Chi or 12,           class = true },
    { key = "ARCANE_CHARGES", label = "Arcane Charges", enum = PT.ArcaneCharges or 16, class = true },
    { key = "ESSENCE",        label = "Essence",        enum = PT.Essence or 19,       class = true },
}

ResourceBars.PowerTypesByEnum = {}
for _, power in ipairs(ResourceBars.PowerTypes) do
    ResourceBars.PowerTypesByEnum[power.enum] = power.key
end

ResourceBars.ClassPowers = {
    DEATHKNIGHT = "RUNES",
    DRUID       = "COMBO_POINTS",
    EVOKER      = "ESSENCE",
    MAGE        = "ARCANE_CHARGES",
    MONK        = "CHI",
    PALADIN     = "HOLY_POWER",
    ROGUE       = "COMBO_POINTS",
    WARLOCK     = "SOUL_SHARDS",
}

ResourceBars.ClassPowersByKey = {}
for _, power in ipairs(ResourceBars.PowerTypes) do
    ResourceBars.ClassPowersByKey[power.key] = power.enum
end

local function resourceBarsAddon()
    local Lite = ItruliaEUI.EUI and ItruliaEUI.EUI.Lite

    if not (Lite and Lite.GetAddon) then
        return nil
    end

    return Lite.GetAddon("EllesmereUIResourceBars", true)
end


local function primaryKey()
    return ResourceBars.PowerTypesByEnum[UnitPowerType("player")]
end

local function classKey()
    local _, class = UnitClass("player")
    local key = class and ResourceBars.ClassPowers[class]

    if not key then
        return nil
    end

    local max = UnitPowerMax("player", ResourceBars.ClassPowersByKey[key])

    if not max or max <= 0 then
        return nil
    end

    return key
end

local function textureName(key)
    local textures = ResourceBars.db and ResourceBars.db.textures

    return key and textures and textures[key] or nil
end

local function mediaKey(name)
    return "sm:" .. name
end

local function texturePath(name)
    return ItruliaEUI.LSM:Fetch("statusbar", name)
end

local function paintBar(bar, path)
    if not (bar and path) then
        return
    end

    local sb = bar._sb

    if sb and sb.SetStatusBarTexture then
        sb:SetStatusBarTexture(path)
    elseif bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(path)
    end
end

local function pipsOf(frame)
    local found = {}

    if not frame then
        return found
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        if type(child.ApplyTexture) == "function" then
            found[#found + 1] = child
        end
    end

    return found
end

local function paintPips(key)
    for _, pip in ipairs(pipsOf(_G.ERB_SecondaryFrame)) do
        pip:ApplyTexture(key)
    end
end

local function secondaryConfig()
    local ERB = resourceBarsAddon()
    local profile = ERB and ERB.db and ERB.db.profile

    if not profile then
        return nil
    end

    local resolve = _G._ERB_ResolveSecondaryCfg

    return (resolve and resolve(profile)) or profile.secondary
end

local function pipBackdrop(pip)
    local tex = pip._itruliaSplitBg

    if not tex then
        -- Sub-layer -2, behind EllesmereUI's own pip background, so the
        -- empty-slot tint it maintains still reads on top of ours.
        tex = pip:CreateTexture(nil, "BACKGROUND", nil, -2)
        tex:SetAllPoints(pip)
        pip._itruliaSplitBg = tex
    end

    return tex
end

local function applySplit(key)
    local frame = _G.ERB_SecondaryFrame

    if not frame then
        return
    end

    local pips = pipsOf(frame)

    if #pips == 0 then
        return
    end

    local sp = secondaryConfig()

    if not sp then
        return
    end

    local split = (key and ResourceBars.db.split[key]) and true or false


    local r, g, b, a
    if sp.darkTheme then
        r, g, b, a = 0, 0, 0, 1
    else
        r, g, b, a = sp.barBgR or 0, sp.barBgG or 0, sp.barBgB or 0, sp.barBgA or 0.5
    end

    for _, pip in ipairs(pips) do
        if split then
            pip:ApplyBorder(sp.borderSize, sp.borderR, sp.borderG, sp.borderB, sp.borderA,
                sp.borderTexture, sp.borderTextureOffset, sp.borderTextureOffsetY,
                sp.borderTextureShiftX, sp.borderTextureShiftY, "resourcebars", sp.borderSize)

            local tex = pipBackdrop(pip)
            tex:SetColorTexture(r, g, b, a)
            tex:Show()
        elseif pip._itruliaSplitBg then
            pip._itruliaSplitBg:Hide()
            pip:ApplyBorder(0, 0, 0, 0, 0)
        end
    end

    local border = frame._barBorder

    if border and border.ApplyStyle then
        border:ApplyStyle(split and 0 or sp.borderSize, sp.borderR, sp.borderG, sp.borderB, sp.borderA,
            sp.borderTexture, sp.borderTextureOffset, sp.borderTextureOffsetY,
            sp.borderTextureShiftX, sp.borderTextureShiftY, "resourcebars", sp.borderSize)
    end

    if frame._barBg then
        if split then
            frame._barBg:Hide()
        elseif (sp.fillOpacity or 100) >= 100 then
            frame._barBg:SetColorTexture(r, g, b, a)
            frame._barBg:Show()
        end
    end
end

function ResourceBars:ApplyTextures()
    if not (self.db and self.db.enabled) then
        return
    end

    local primaryTexture = textureName(primaryKey())

    if primaryTexture then
        paintBar(_G.ERB_PrimaryBar, texturePath(primaryTexture))
    end

    local class = classKey()
    local classTexture = textureName(class)

    if classTexture then
        paintBar(_G.ERB_SecondaryBar, texturePath(classTexture))
        paintPips(mediaKey(classTexture))
    end

    applySplit(class)
end

local pending = false

local function schedule()
    if pending or not (ResourceBars.db and ResourceBars.db.enabled) then
        return
    end

    pending = true

    C_Timer.After(0, function()
        pending = false
        ResourceBars:ApplyTextures()
    end)
end

local function OnEvent(_, event, unit)
    if event == "UNIT_DISPLAYPOWER" and unit ~= "player" then
        return
    end

    schedule()
end

function ResourceBars:LoadDB()
    local profile = ItruliaEUI.db.profile
    profile[moduleName] = profile[moduleName] or self:GetDefaults()

    return profile[moduleName]
end

function ResourceBars:OnInitialize()
    self.db = self:LoadDB()
end

function ResourceBars:RefreshConfig()
    self.db = self:LoadDB()

    if not self.db.enabled then
        if self.frame then
            self.frame:UnregisterAllEvents()
        end

        for _, pip in ipairs(pipsOf(_G.ERB_SecondaryFrame)) do
            if pip._itruliaSplitBg then
                pip._itruliaSplitBg:Hide()
            end
        end

        local ERB = resourceBarsAddon()

        if ERB and ERB.ApplyAll then
            ERB:ApplyAll()
        end

        return
    end

    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", OnEvent)

    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.frame:RegisterEvent("UNIT_DISPLAYPOWER")
    self.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

    if not self._applyAllHooked then
        local ERB = resourceBarsAddon()

        if ERB and ERB.ApplyAll then
            self._applyAllHooked = true

            hooksecurefunc(ERB, "ApplyAll", function()
                schedule()
            end)
        end
    end

    self:ApplyTextures()
end

function ResourceBars:OnEnable()
    self:RefreshConfig()
end
