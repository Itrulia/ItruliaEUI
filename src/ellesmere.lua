local addonName, ItruliaEUI = ...

-- EllesmereUI integration -- the only settings host this addon has.
--
-- Almost none of the work happens here. ItruliaQoL already solved this problem --
-- the row renderer, the widget helpers, the page builder, the loadstring
-- trampoline that gets past EllesmereUI's caller whitelist and the sidebar enable
-- switches all live in its src/integrations/ellesmere/ellesmere.lua, and its
-- ellesmere-options.md documents the row format that options.eui.lua files author
-- against. This file is the small part that cannot be borrowed: which sidebar
-- group the rows belong to, and which addon's modules fill them.
--
-- ItruliaQoL's own RegisterEUI is not reusable as-is on purpose. It resolves
-- modules against ItruliaQoL's registry, prefixes row keys with its own addon
-- name, and reads the row names out of an AceConfig tree this addon does not
-- build. Everything below it, though, takes plain arguments and is reused
-- untouched.

-- Our own sidebar group, so these rows sit under their own heading instead of
-- being mixed into ItruliaQoL's.
local GROUP_KEY   = "itruliaeui"

-- The name in the addon's own colours (the same escape sequence as `## Title` in
-- the .toc, so it reads the way the addon does in the AddOns list). Both places
-- EllesmereUI renders it -- the sidebar group heading and the panel header above
-- each of our pages -- are FontStrings, so the escape codes apply.
--
-- Embedded |cff codes win over SetTextColor, which is the point for the sidebar
-- heading: EllesmereUI tints group labels with its accent colour (and re-applies
-- it from an accent callback), leaving "Itrulia EUI" indistinguishable from its
-- own groups.
--
-- The rows' plain-text `search_name` keeps the uncoloured spelling, since that is
-- matched against the player's query rather than drawn.
local GROUP_LABEL_COLORED = "|cffe9e9edItrulia|r |cff3fbf9fEUI|r"

local PAGE_GENERAL  = "General"
local PAGE_SETTINGS = "Settings"

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

    local PAD_X, PAD_Y = 12, 10
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
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -PAD_Y)
    title:SetText("INOFFICIAL MODULE")

    local support = frame:CreateFontString(nil, "OVERLAY")
    support:SetFont(fontPath, 12, "")
    support:SetTextColor(1, 0.85, 0.5, 0.9)
    support:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    support:SetWidth(availW - PAD_X * 2)
    support:SetJustifyH("LEFT")
    support:SetWordWrap(true)
    support:SetText("Itrulia EUI is an inofficial module and not part of EllesmereUI. Please do not ask about it in the EllesmereUI Discord. Message Itrulia on Discord directly instead.")

    local height = PAD_Y + title:GetStringHeight() + 6 + support:GetStringHeight() + PAD_Y + 8
    PP.Size(frame, availW, height)
    PP.CreateBorder(frame, 0.95, 0.65, 0.15, 1, 1)

    return frame, height
end

-- Addon-wide settings, from general/options.eui.lua. The module pages go through
-- ItruliaQoL:BuildEUIModulePage; this one has no module to hand it.
function ItruliaEUI:BuildGeneralPage(parent, yOffset)
    local QoL = self.QoL
    local W = self.EUI.Widgets
    local y = yOffset
    local _, h

    _, h = W:Spacer(parent, y, 8)
    y = y - h
    _, h = W:SectionHeader(parent, "GENERAL", y)
    y = y - h

    local spec = self:GetGeneralEUIOptions()

    if spec and spec.rows then
        y = QoL:RenderEUIList(W, parent, y, spec.rows)
    end

    return math.abs(y)
end

-- EllesmereUI keeps its sidebar as a list of groups of "addon folders". Our rows
-- are not real folders, so they are declared here and marked exempt from the
-- install-state sync that would otherwise grey them out.
--
-- Member order is authoritative, so a repeat call replaces the list rather than
-- bailing out -- otherwise a changed module set keeps the stale rows.
function ItruliaEUI:InjectSidebar(entries)
    local EUI = self.EUI

    EUI._addonInfoByFolder = EUI._addonInfoByFolder or {}
    EUI._syncExempt = EUI._syncExempt or {}

    local members = {}

    for _, entry in ipairs(entries) do
        EUI._addonInfoByFolder[entry.key] = EUI._addonInfoByFolder[entry.key] or {
            folder = entry.key,
            display = entry.display,
            search_name = entry.display .. " Itrulia EUI Itrulia",
            alwaysLoaded = true,
        }

        EUI._syncExempt[entry.key] = true
        members[#members + 1] = entry.key
    end

    EUI.ADDON_GROUPS = EUI.ADDON_GROUPS or {}

    for _, group in ipairs(EUI.ADDON_GROUPS) do
        if group.key == GROUP_KEY then
            group.members = members

            return
        end
    end

    -- Appended rather than prepended: a companion addon has no business pushing
    -- EllesmereUI's own suite down the sidebar.
    table.insert(EUI.ADDON_GROUPS, {
        key = GROUP_KEY,
        label = GROUP_LABEL_COLORED,
        members = members,
    })
end

-- Called from OnEnable. Modules are read straight off this addon's own registry:
-- with no AceConfig tree to mine for row names, each declares a static
-- `euiDisplay` and `euiDescription` (see src/template/init.lua). Static rather
-- than pulled from GetEUIOptions, so building the sidebar does not mean invoking
-- every module at login.
function ItruliaEUI:RegisterEUI()
    local EUI = self.EUI
    local QoL = self.QoL

    -- Gate on RegisterModule alone. EUI.Widgets only exists after EllesmereUI's
    -- deferred EnsureLoaded has run, and whether that has happened by now is a
    -- PLAYER_LOGIN handler-order race -- so testing for it here would silently skip
    -- the whole integration depending on the installed addon set. Widgets is only
    -- read from buildPage, which runs on panel open, long after.
    if not (EUI and EUI.RegisterModule and QoL and QoL.RegisterEUIModule) then
        return
    end

    if self._euiRegistered then
        return
    end

    self._euiRegistered = true

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

    -- Keys are namespaced so they can never collide with a real addon folder in
    -- EllesmereUI's roster, or with ItruliaQoL's rows.
    local function addEntry(key, display, pages, build, description, members, notice)
        entries[#entries + 1] = {
            key = addonName .. "_" .. key,
            display = display,
            pages = pages,
            build = build,
            description = description,
            members = members,
            notice = notice,
        }
    end

    addEntry("General", "General", { PAGE_GENERAL }, function(_, parent, y)
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

        addEntry(entry.name, module.euiDisplay or entry.name, module.EUIPages or { PAGE_SETTINGS },
            function(pageName, parent, y)
                return QoL:BuildEUIModulePage(module, parent, y, true, pageName)
            end, module.euiDescription, members)
    end

    self:InjectSidebar(entries)

    -- The row switches only exist once EllesmereUI has built its main frame, and
    -- these three are the only ways in. Attaching is idempotent, so firing on every
    -- open costs nothing.
    if not self._euiSwitchHooked then
        self._euiSwitchHooked = true

        for _, name in ipairs({ "Show", "Toggle", "ShowModule" }) do
            if EUI[name] then
                hooksecurefunc(EUI, name, function()
                    -- Our group key, so the "(Inofficial Module)" note lands on our
                    -- header rather than a second time on ItruliaQoL's.
                    QoL:AttachEUISidebarGroupNote(GROUP_KEY)
                    QoL:AttachEUISidebarSwitches(entries)
                    QoL:RefreshEUISidebarRows(entries)
                end)
            end
        end

        -- SelectModule recolours labels from EllesmereUI's own state, so our disabled
        -- grey has to be reapplied after it.
        if EUI.SelectModule then
            hooksecurefunc(EUI, "SelectModule", function()
                QoL:RefreshEUISidebarRows(entries)
            end)
        end
    end

    for _, entry in ipairs(entries) do
        local build = entry.build

        QoL:RegisterEUIModule(entry.key, {
            title = GROUP_LABEL_COLORED .. " - " .. entry.display,
            description = entry.description or "",
            pages = entry.pages,
            buildPage = function(pageName, parent, yOffset)
                local y = yOffset

                if entry.notice then
                    local _, noticeH = self:RenderNotice(parent, y)
                    y = y - noticeH
                end

                return build(pageName, parent, y) or math.abs(y)
            end,
        })
    end

    -- Test mode follows EllesmereUI's unlock mode, the way ItruliaQoL hooks ElvUI's
    -- ToggleMovers. Keyed by our own addon name so it sits alongside ItruliaQoL's
    -- listener instead of replacing it.
    if EUI.RegisterUnlockModeListener then
        EUI:RegisterUnlockModeListener(addonName, function(active)
            self:ToggleTestMode(active and true or false)
        end)
    end
end
