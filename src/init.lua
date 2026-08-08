local addonName, namespace = ...

ItruliaEUI = LibStub("AceAddon-3.0"):NewAddon(namespace, addonName, "AceConsole-3.0")
ItruliaEUI.LSM = LibStub("LibSharedMedia-3.0")
ItruliaEUI.testMode = false
ItruliaEUI.EUI = _G.EllesmereUI
ItruliaEUI.QoL = _G.ItruliaQoL

function ItruliaEUI:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ItruliaEUIDB", {}, true)

    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshModules")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshModules")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshModules")
end

function ItruliaEUI:OnEnable()
    self:RegisterEUI()
end

function ItruliaEUI:RefreshModules()
    for _, module in self:IterateModules() do
        if module.RefreshConfig then
            module:RefreshConfig()
        end
    end
end

function ItruliaEUI:ApplyModuleStyles(moduleName)
    local module = self:GetModule(moduleName, true)

    if module and module.db and module.db.enabled == false then
        return
    end

    local frame = _G[addonName .. moduleName]

    if frame and frame.UpdateStyles then
        frame:UpdateStyles()
    end
end

function ItruliaEUI:ToggleTestMode(enabled)
    self.testMode = enabled

    for _, module in self:IterateModules() do
        if module.ToggleTestMode then
            module:ToggleTestMode(enabled)
        end
    end
end

ItruliaEUI:RegisterChatCommand("ieui", "SlashProcessor")

function ItruliaEUI:SlashProcessor(input)
    local arg = input and input:lower():match("^%s*(%S*)") or ""

    if arg == "" or arg == "config" or arg == "c" then
        if self.EUI and self.EUI.ShowModule then
            self.EUI:ShowModule(addonName .. "_General")
        else
            self:Print("|cffff8000EllesmereUI is not available|r -- these settings have no other panel.")
        end
    elseif arg == "test" or arg == "t" then
        self:ToggleTestMode(not self.testMode)
    else
        self:Print("AddOn commands:")
        self:Print("/ieui")
        self:Print("/ieui config")
        self:Print("/ieui test")
    end
end
