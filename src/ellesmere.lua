local addonName, ItruliaEUI = ...

-- EllesmereUI integration, the only settings host this addon has.
--
-- Almost none of the work happens here. ItruliaQoL already solved this problem:
-- the row renderer, the widget helpers, the page builder and the registration
-- itself all live in its src/integrations/ellesmere/ellesmere.lua, and its
-- ellesmere-options.md documents the row format that options.eui.lua files author
-- against. Its RegisterEUISection hands our rows to EllesmereUI's Plugin API
-- (EllesmereUI/PLUGINS_API.md) as a sidebar section of their own, and adds what
-- the API has no field for: the coloured header, the "(Inofficial Module)" note,
-- the per-row enable switches and the row `/ieui` reopens. This file is the small
-- part that cannot be borrowed: which section the rows belong to, and which
-- addon's modules fill them.
--
-- ItruliaQoL's own RegisterEUI is not reusable as-is on purpose. It resolves
-- modules against ItruliaQoL's registry, files them into its own sections, and
-- reads the row names out of an AceConfig tree this addon does not build.
-- Everything below it, though, takes plain arguments and is reused untouched.

-- Names our section in ItruliaQoL's registry, which remembers the row `/ieui`
-- reopens per group key, so ours is kept apart from ItruliaQoL's own.
local groupKey = "itruliaeui"

-- The section header as EllesmereUI registers and searches it. Plain text: the
-- Plugin API strips colour codes from labels and refuses one that starts with
-- "EllesmereUI" or "EUI".
local groupLabel = "Itrulia EUI"

-- The name in the addon's own colours (the same escape sequence as `## Title` in
-- the .toc, so it reads the way the addon does in the AddOns list). ItruliaQoL
-- sets it on the section header once EllesmereUI has built it, in place of the
-- plain label.
--
-- Embedded |cff codes win over SetTextColor, which is the point for the sidebar
-- heading: EllesmereUI tints section headers with its accent colour (and re-applies
-- it from an accent callback), leaving "Itrulia EUI" indistinguishable from its
-- own sections.
local groupLabelColored = "|cffe9e9edItrulia|r |cff3fbf9fEUI|r"

local pageGeneral      = "General"
local pageSettings     = "Settings"
local pageProfiles     = "Profiles"
local pageImportExport = "Import / Export"

-- "Inofficial module" disclaimer at the top of the General page, modelled on
-- ItruliaQoL's beta notice minus its beta framing: this addon has no ElvUI or
-- standalone panel to send anyone to, so there is neither a "still being built"
-- line nor a link out -- just the one line that saves the EllesmereUI Discord a
-- support request that is not theirs to answer.
function ItruliaEUI:RenderNotice(parent, y)
    local EUI = self.EUI
    local PP = EUI.PanelPP or EUI.PP
    local pad = EUI.CONTENT_PAD or 0
    local fontPath = (EUI.GetFontPath and EUI.GetFontPath()) or STANDARD_TEXT_FONT

    local padX, padY = 12, 10
    local availW = parent:GetWidth() - pad * 2

    local frame = CreateFrame("Frame", nil, parent)
    PP.Point(frame, "TOPLEFT", parent, "TOPLEFT", pad, y)
    PP.Size(frame, availW, 1) -- provisional; resized once the text has wrapped

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.85, 0.55, 0.1, 0.12)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(fontPath, 16, "OUTLINE")
    title:SetTextColor(1, 0.75, 0.2, 1)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", padX, -padY)
    title:SetText("INOFFICIAL MODULE")

    local support = frame:CreateFontString(nil, "OVERLAY")
    support:SetFont(fontPath, 12, "")
    support:SetTextColor(1, 0.85, 0.5, 0.9)
    support:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    support:SetWidth(availW - padX * 2)
    support:SetJustifyH("LEFT")
    support:SetWordWrap(true)
    support:SetText("Itrulia EUI is an inofficial module and not part of EllesmereUI. Please do not ask about it in the EllesmereUI Discord. Message Itrulia on Discord directly instead.")

    local height = padY + title:GetStringHeight() + 6 + support:GetStringHeight() + padY + 8
    PP.Size(frame, availW, height)
    PP.CreateBorder(frame, 0.95, 0.65, 0.15, 1, 1)

    return frame, height
end

-- Addon-wide settings, from general/options.eui.lua. The module pages go through
-- ItruliaQoL:BuildEUIModulePage; this one has no module to hand it.
function ItruliaEUI:BuildGeneralPage(parent, yOffset)
    local QoL = self.QoL
    local widgets = self.EUI.Widgets
    local y = yOffset
    local _, h

    _, h = widgets:Spacer(parent, y, 8)
    y = y - h
    _, h = widgets:SectionHeader(parent, "GENERAL", y)
    y = y - h

    local spec = self:GetGeneralEUIOptions()

    if spec and spec.rows then
        y = QoL:RenderEUIList(widgets, parent, y, spec.rows)
    end

    return math.abs(y)
end

-- Called from OnEnable. Modules are read straight off this addon's own registry:
-- with no AceConfig tree to mine for row names, each declares a static
-- `euiDisplay` and `euiDescription` (see src/minimap/init.lua). Static rather
-- than pulled from GetEUIOptions, so building the sidebar does not mean invoking
-- every module at login.
function ItruliaEUI:RegisterEUI()
    local EUI = self.EUI
    local QoL = self.QoL

    if not EUI or self._euiRegistered then
        return
    end

    self._euiRegistered = true

    -- Test mode follows EllesmereUI's unlock mode, the way ItruliaQoL hooks ElvUI's
    -- ToggleMovers. Keyed by our own addon name so it sits alongside ItruliaQoL's
    -- listener instead of replacing it. Ahead of the plugin check: unlock mode works
    -- on an EllesmereUI too old for RegisterPlugin as well.
    if EUI.RegisterUnlockModeListener then
        EUI:RegisterUnlockModeListener(addonName, function(active)
            self:ToggleTestMode(active and true or false)
        end)
    end

    -- Never gate on EUI.Widgets here. It only exists after EllesmereUI's deferred
    -- EnsureLoaded has run, and whether that has happened by now is a PLAYER_LOGIN
    -- handler-order race, so testing for it would silently skip the whole
    -- integration depending on the installed addon set. Widgets is only read from
    -- buildPage, which runs on panel open, long after.
    if not (EUI.RegisterPlugin and QoL and QoL.RegisterEUISection) then
        return
    end

    local modules = {}

    for name, module in self:IterateModules() do
        -- No options.eui.lua means no row: it would open an empty page.
        if module.GetEUIOptions then
            modules[#modules + 1] = { name = name, module = module }
        end
    end

    -- Alphabetical by the name the row shows -- a flat sidebar has no themed
    -- grouping to preserve.
    table.sort(modules, function(a, b)
        return (a.module.euiDisplay or a.name) < (b.module.euiDisplay or b.name)
    end)

    local entries = {}

    -- Keys stay plain, EllesmereUI namespaces them under our plugin id itself. A key
    -- has to match ^%a[%w_%-]*$ and a page name has to be plain text without `|`,
    -- module names and EUIPages included: RegisterPlugin rejects the whole section
    -- over a single bad one.
    local function addEntry(key, display, pages, build, description, members, notice)
        entries[#entries + 1] = {
            key = key,
            display = display,
            description = description,
            pages = pages,
            members = members,
            buildPage = function(pageName, parent, yOffset)
                if notice then
                    local _, noticeHeight = self:RenderNotice(parent, yOffset)
                    yOffset = yOffset - noticeHeight
                end

                return build(pageName, parent, yOffset) or math.abs(yOffset)
            end,
        }
    end

    addEntry("General", "General", { pageGeneral }, function(_, parent, y)
        return self:BuildGeneralPage(parent, y)
    end, "Settings for the EllesmereUI-specific pieces of Itrulia's setup.", nil, true)

    for _, entry in ipairs(modules) do
        local module = entry.module

        -- Modules with nothing to turn off opt out of the row's enable switch by
        -- setting EUINoEnableSwitch; no members means no switch.
        local members

        if not module.EUINoEnableSwitch then
            members = { { key = entry.name, module = module } }
        end

        addEntry(entry.name, module.euiDisplay or entry.name, module.EUIPages or { pageSettings },
            function(pageName, parent, y)
                return QoL:BuildEUIModulePage(module, parent, y, true, pageName)
            end, module.euiDescription, members)
    end

    -- Last, after the modules, so the sidebar reads settings-then-housekeeping the
    -- way ItruliaQoL's main section does. Both pages are ItruliaQoL's, pointed at this
    -- addon's own database and profile strings by the `self` argument.
    addEntry("Profiles", "Profiles", { pageProfiles, pageImportExport }, function(pageName, parent, y)
        if pageName == pageImportExport then
            return QoL:BuildEUIImportExportPage(parent, y, self)
        end

        return QoL:BuildEUIProfilesPage(parent, y, self)
    end, "Profiles")

    QoL:RegisterEUISection(groupKey, {
        id = addonName,
        label = groupLabel,
        labelColored = groupLabelColored,
        note = true,
        entries = entries,
    })
end

-- `/ieui` reopens the row it was left on, General on the first open of a session,
-- with the sidebar scrolled to it, since our section sits below EllesmereUI's own
-- suite. Both come from ItruliaQoL's OpenEUIGroup, which remembers the row per
-- group key, so ours is not its.
--
-- False tells the caller EllesmereUI is not available, so it follows whether our
-- section registered rather than whether the panel opened: in combat EllesmereUI
-- refuses to open and says so itself.
function ItruliaEUI:OpenEUI()
    local QoL = self.QoL

    if not (QoL and QoL.IsEUIGroupRegistered and QoL:IsEUIGroupRegistered(groupKey)) then
        return false
    end

    QoL:OpenEUIGroup(groupKey, "General")

    return true
end
