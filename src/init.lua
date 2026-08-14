local addonName, namespace = ...

ItruliaEUI = LibStub("AceAddon-3.0"):NewAddon(namespace, addonName, "AceConsole-3.0")
ItruliaEUI.LSM = LibStub("LibSharedMedia-3.0")
ItruliaEUI.testMode = false
ItruliaEUI.EUI = _G.EllesmereUI
ItruliaEUI.QoL = _G.ItruliaQoL

local AceSerializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

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

function ItruliaEUI:ExportCurrentProfile()
    local profileName = self.db:GetCurrentProfile()
    local profileData = self.db.profiles[profileName]

    local serialized = AceSerializer:Serialize(profileData)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)

    return addonName .. encoded
end

function ItruliaEUI:DecodeImportString(str)
    if type(str) ~= "string" or not str:find("^" .. addonName) then
        return false, "Missing or invalid prefix"
    end

    local payload = str:sub(#addonName + 1)

    local decoded = LibDeflate:DecodeForPrint(payload)
    if not decoded then
        return false, "Invalid encoded data"
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return false, "Decompression failed"
    end

    local success, data = AceSerializer:Deserialize(decompressed)
    if not success or type(data) ~= "table" then
        return false, "Invalid serialized profile"
    end

    return true, data
end

local function finish(callback, ok, err)
    if callback then
        callback(ok, err)
    end

    return ok, err
end

function ItruliaEUI:ImportAsNewProfile(str, profileName, override, callback)
    if not profileName or profileName == "" then
        return finish(callback, false, "Invalid profile name")
    end

    if self.db.profiles[profileName] and not override then
        return finish(callback, false, "Profile already exists")
    end

    local ok, data = self:DecodeImportString(str)
    if not ok then
        return finish(callback, false, data)
    end

    self.db:SetProfile(profileName)

    local profile = self.db.profile
    for k in pairs(profile) do
        profile[k] = nil
    end

    for k, v in pairs(data) do
        profile[k] = v
    end

    self:RefreshModules()

    return finish(callback, true)
end

function ItruliaEUI:ImportIntoCurrentProfile(str, callback)
    local ok, dataOrErr = self:DecodeImportString(str)
    if not ok then
        return finish(callback, false, dataOrErr)
    end

    local profile = self.db.profile

    for k in pairs(profile) do
        profile[k] = nil
    end

    for k, v in pairs(dataOrErr) do
        profile[k] = v
    end

    self:RefreshModules()

    return finish(callback, true)
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
            self:Print("|cffff8000EllesmereUI is not available|r. These settings have no other panel.")
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
