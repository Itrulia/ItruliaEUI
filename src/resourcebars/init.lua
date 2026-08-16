local addonName, ItruliaEUI = ...
local moduleName = "ResourceBars"

local ResourceBars = ItruliaEUI:NewModule(moduleName)
ResourceBars.euiDisplay = "Resource Bars"
ResourceBars.euiDescription = "Give each power type its own statusbar texture on EllesmereUI's resource and class bars and allow splitting the individual resource items."

local powerType = Enum and Enum.PowerType or {}

ResourceBars.PowerTypes = {
    { key = "MANA",           label = "Mana",           enum = powerType.Mana or 0 },
    { key = "RAGE",           label = "Rage",           enum = powerType.Rage or 1 },
    { key = "FOCUS",          label = "Focus",          enum = powerType.Focus or 2 },
    { key = "ENERGY",         label = "Energy",         enum = powerType.Energy or 3 },
    { key = "RUNIC_POWER",    label = "Runic Power",    enum = powerType.RunicPower or 6 },
    { key = "LUNAR_POWER",    label = "Astral Power",   enum = powerType.LunarPower or 8 },
    { key = "MAELSTROM",      label = "Maelstrom",      enum = powerType.Maelstrom or 11 },
    { key = "INSANITY",       label = "Insanity",       enum = powerType.Insanity or 13 },
    { key = "FURY",           label = "Fury",           enum = powerType.Fury or 17 },
    { key = "PAIN",           label = "Pain",           enum = powerType.Pain or 18 },
    { key = "COMBO_POINTS",   label = "Combo Points",   enum = powerType.ComboPoints or 4,    class = true },
    { key = "RUNES",          label = "Runes",          enum = powerType.Runes or 5,          class = true },
    { key = "SOUL_SHARDS",    label = "Soul Shards",    enum = powerType.SoulShards or 7,     class = true },
    { key = "HOLY_POWER",     label = "Holy Power",     enum = powerType.HolyPower or 9,      class = true },
    { key = "CHI",            label = "Chi",            enum = powerType.Chi or 12,           class = true },
    { key = "ARCANE_CHARGES", label = "Arcane Charges", enum = powerType.ArcaneCharges or 16, class = true },
    { key = "ESSENCE",        label = "Essence",        enum = powerType.Essence or 19,       class = true },
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

-- `size` is separate from sp.borderSize, which stays the border texture's size
-- key: a border drawn at 0 still has to look up the configured size's texture.
local function borderArgs(sp, size)
    return size, sp.borderR, sp.borderG, sp.borderB, sp.borderA,
        sp.borderTexture, sp.borderTextureOffset, sp.borderTextureOffsetY,
        sp.borderTextureShiftX, sp.borderTextureShiftY, "resourcebars", sp.borderSize
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

    -- No key is not an instruction to unify: UnitPowerMax reads 0 for a moment on
    -- a taxi, in a vehicle and mid spec change, and unsplitting there sticks.
    if not key then
        return
    end

    local split = ResourceBars.db.split[key] and true or false

    -- Nothing of ours on the bar and none wanted, so leave it to EllesmereUI
    -- rather than clearing borders it drew itself.
    if not (split or frame._itruliaSplit) then
        return
    end

    local r, g, b, a
    if sp.darkTheme then
        r, g, b, a = 0, 0, 0, 1
    else
        r, g, b, a = sp.barBgR or 0, sp.barBgG or 0, sp.barBgB or 0, sp.barBgA or 0.5
    end

    for _, pip in ipairs(pips) do
        if split then
            pip._itruliaSplit = true
            pip:ApplyBorder(borderArgs(sp, sp.borderSize))

            local tex = pipBackdrop(pip)
            tex:SetColorTexture(r, g, b, a)
            tex:Show()
        elseif pip._itruliaSplit then
            pip._itruliaSplit = nil

            if pip._itruliaSplitBg then
                pip._itruliaSplitBg:Hide()
            end

            -- With "Border on pips" on, the pip has a border of EllesmereUI's own,
            -- so clearing outright strips one we never drew.
            if sp.borderOnPips then
                pip:ApplyBorder(borderArgs(sp, sp.borderSize))
            else
                pip:ApplyBorder(0, 0, 0, 0, 0)
            end
        end
    end

    frame._itruliaSplit = split or nil

    local border = frame._barBorder

    if border and border.ApplyStyle then
        -- EllesmereUI drops the container border when each pip carries its own,
        -- runes excepted, where it keeps both.
        local pipsOwnBorder = sp.borderOnPips and key ~= "RUNES"

        border:ApplyStyle(borderArgs(sp, (split or pipsOwnBorder) and 0 or sp.borderSize))
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

        local frame = _G.ERB_SecondaryFrame

        for _, pip in ipairs(pipsOf(frame)) do
            pip._itruliaSplit = nil

            if pip._itruliaSplitBg then
                pip._itruliaSplitBg:Hide()
            end
        end

        if frame then
            frame._itruliaSplit = nil
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

    local ERB = resourceBarsAddon()

    if ERB and not self._applyAllHooked and ERB.ApplyAll then
        self._applyAllHooked = true

        hooksecurefunc(ERB, "ApplyAll", function()
            schedule()
        end)
    end

    -- Every rebuild re-applies EllesmereUI's own pip borders and container
    -- background, wiping the split, and most events that rebuild the bar (a max
    -- power change, landing from a flight path, a talent or form swap) call its
    -- internal BuildBars without going through ApplyAll. ApplyGapFills is the one
    -- function BuildBars calls on every branch, so this catches the rest.
    if ERB and not self._gapFillsHooked and ERB.ApplyGapFills then
        self._gapFillsHooked = true

        hooksecurefunc(ERB, "ApplyGapFills", function()
            schedule()
        end)
    end

    self:ApplyTextures()
end

function ResourceBars:OnEnable()
    self:RefreshConfig()
end
