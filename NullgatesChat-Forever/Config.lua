--[[
    Nullgate's Chat - Config.lua
    Data Layer: SavedVariables Schema, Non-Destructive Profiles,
    Master Hub Integration & Slash Command Dispatcher
]]

local addonName, BFC = ...
BFC = BFC or {}
_G["NullgatesChat"] = BFC

BFC.addonName = addonName
BFC.version = "1.0.9"

--[[-----------------------------------------------------------------------------
    SavedVariables Schema & Default Settings
-------------------------------------------------------------------------------]]
local DB_DEFAULTS = {
    profile = {
        -- General & URL Links
        enableUrlLinks = true,
        urlColor = { r = 0.20, g = 0.85, b = 1.00 }, -- Bright Cyan accent

        -- Whispers to New Window / Tab by Default
        whisperWindow = true,
        whisperNotifyGlow = true,

        -- Universal Character Name Class Coloring
        classColorNames = true,

        -- Channels & Formatting
        shortChannelNames = true,
        showTimestamps = true,
        timestampFormat = "%H:%M",
        timestampColor = { r = 0.55, g = 0.58, b = 0.63 },

        -- Persistent History & Command Memory
        enableChatHistory = true,
        chatHistoryLines = 200,      -- Lines per chat tab (50 - 500)
        showSessionDivider = true,
        enableEditBoxHistory = true,
        editBoxHistoryLines = 50,
        stickyChannels = true,

        -- EditBox & Frame Layout
        editBoxPosition = "BOTTOM",  -- "BOTTOM" or "TOP"
        editBoxBackdrop = true,      -- Dark Slate & Gold EditBox Skinning
        showCopyButton = true,       -- Show copy button on chat frames
        hideChatButtons = true,      -- Hides chat menu, voice, channel buttons
        hideScrollButtons = true,    -- Hides bottom scroll buttons
        enableMouseWheel = true,     -- Mousewheel scroll (Shift+Wheel to jump)
        unclampFromScreen = true,    -- Move flush to screen edges
        enableCustomBackdrop = false,
        backdropAlpha = 0.65,

        -- Typography
        font = "Nata Sans Regular",
        fontSize = 12,
        fontOutline = "OUTLINE",

        -- Theme & Palette
        theme = {
            bgR = 0.08,
            bgG = 0.10,
            bgB = 0.13,
            bgA = 0.96,
            borderR = 0.82,
            borderG = 0.68,
            borderB = 0.28,
            borderA = 1.0,
        },
    }
}

BFC.DB_DEFAULTS = DB_DEFAULTS

--[[-----------------------------------------------------------------------------
    Database Initialization
-------------------------------------------------------------------------------]]
function BFC:InitDB()
    if LibStub and LibStub("AceDB-3.0", true) then
        self.dbObject = LibStub("AceDB-3.0"):New("NullgatesChatDB", DB_DEFAULTS, true)
        self.db = self.dbObject.profile

        self.dbObject.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
        self.dbObject.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
        self.dbObject.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    else
        -- Fallback standalone persistence
        NullgatesChatDB = NullgatesChatDB or {}
        local raw = NullgatesChatDB
        local def = DB_DEFAULTS.profile

        for k, v in pairs(def) do
            if raw[k] == nil then
                if type(v) == "table" then
                    raw[k] = CopyTable and CopyTable(v) or {}
                else
                    raw[k] = v
                end
            end
        end
        self.db = raw
    end

    -- Global chat history container
    _G["NullgatesChatHistory"] = _G["NullgatesChatHistory"] or {}
    self.historyDB = _G["NullgatesChatHistory"]
end

function BFC:OnProfileChanged()
    if self.dbObject then
        self.db = self.dbObject.profile
    end

    if self.ApplySettings then
        self:ApplySettings()
    end

    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

--[[-----------------------------------------------------------------------------
    Profile Management Helpers (Non-Destructive)
-------------------------------------------------------------------------------]]
function BFC:GetActiveProfile()
    return (self.dbObject and self.dbObject.GetCurrentProfile and self.dbObject:GetCurrentProfile()) or "Default"
end

function BFC:GetProfileList()
    if self.dbObject and self.dbObject.GetProfiles then
        return self.dbObject:GetProfiles()
    end
    return { "Default" }
end

function BFC:SetProfile(profileKey)
    if not profileKey or profileKey == "" then return end
    if self.dbObject and self.dbObject.SetProfile then
        self.dbObject:SetProfile(profileKey)
    end
end

function BFC:CreateProfile(profileKey)
    if not profileKey or profileKey == "" then return end
    if self.dbObject and self.dbObject.SetProfile then
        local current = self:GetActiveProfile()
        self.dbObject:SetProfile(profileKey)
        -- NON-DESTRUCTIVE: Clone current active settings into the newly created profile!
        if current and current ~= profileKey and self.dbObject.CopyProfile then
            self.dbObject:CopyProfile(current)
        end
    end
end

function BFC:CopyProfile(fromKey)
    if not fromKey or fromKey == "" then return end
    if self.dbObject and self.dbObject.CopyProfile then
        self.dbObject:CopyProfile(fromKey)
    end
end

function BFC:ResetProfile()
    if self.dbObject and self.dbObject.ResetProfile then
        self.dbObject:ResetProfile()
    end
end

function BFC:DeleteProfile(profileKey)
    if not profileKey or profileKey == "Default" then return end
    if self.dbObject and self.dbObject.DeleteProfile then
        self.dbObject:DeleteProfile(profileKey)
    end
end

--[[-----------------------------------------------------------------------------
    Soft Register with NullgatesAddonConfigForever (Master Hub)
-------------------------------------------------------------------------------]]
function BFC:RegisterWithMasterConfig()
    local BAC = _G["NullgatesAddonConfigForever"] or _G["NullgatesAddonConfig"]
    if not (BAC and BAC.RegisterModule) then
        return
    end

    BAC:RegisterModule("NullgatesChat", {
        id = "NullgatesChat",
        name = "Nullgate's Chat",
        sidebarName = "Chat",
        version = self.version,
        author = "Nullgate Studios",
        isNullgate = true,
        description = "High-performance, minimalist chat suite featuring link clicking, persistent history, whisper popouts, and class colors.",
        db = self.db,
        getDB = function() return BFC.db end,
        buildUI = function(container, isMasterHub)
            if BFC.UI and BFC.UI.BuildOptions then
                BFC.UI:BuildOptions(container, isMasterHub)
            end
        end,
        refresh = function()
            if BFC.UI and BFC.UI.Refresh then
                BFC.UI:Refresh()
            end
            if BFC.ApplySettings then
                BFC:ApplySettings()
            end
        end,
        profiles = {
            GetCurrent = function()
                return BFC:GetActiveProfile()
            end,
            SetCurrent = function(profileKey)
                BFC:SetProfile(profileKey)
            end,
            GetList = function()
                return BFC:GetProfileList()
            end,
            Create = function(profileKey)
                BFC:CreateProfile(profileKey)
            end,
            Delete = function(profileKey)
                BFC:DeleteProfile(profileKey)
            end,
            Copy = function(fromKey, toKey)
                BFC:CopyProfile(fromKey)
            end,
            Reset = function(profileKey)
                BFC:ResetProfile()
            end,
        },
        openConfig = function()
            BFC:OpenSettings()
        end,
    })
end

function BFC:OpenSettings()
    local BAC = _G["NullgatesAddonConfigForever"] or _G["NullgatesAddonConfig"]
    if BAC and (BAC.OpenToModule or BAC.SelectModule) and not IsShiftKeyDown() then
        if BAC.OpenToModule then
            BAC:OpenToModule("NullgatesChat")
        elseif BAC.SelectModule then
            if BAC.ShowUI then BAC:ShowUI() end
            BAC:SelectModule("NullgatesChat")
        end
    elseif self.UI and self.UI.ToggleStandaloneWindow then
        self.UI:ToggleStandaloneWindow()
    else
        print("|cff00c0ffNullgate's Chat:|r Settings UI is loading...")
    end
end

--[[-----------------------------------------------------------------------------
    Slash Commands Handler
-------------------------------------------------------------------------------]]
SLASH_NULLGATESCHAT1 = "/nchat"
SLASH_NULLGATESCHAT2 = "/chat"

SlashCmdList["NULLGATESCHAT"] = function(msg)
    local cmd = msg and msg:trim():lower() or ""
    local arg1, arg2 = cmd:match("^(%S+)%s*(.*)$")

    if arg1 == "config" or arg1 == "options" or arg1 == "settings" or cmd == "" then
        BFC:OpenSettings()
    elseif arg1 == "copy" then
        if BFC.OpenActiveChatCopy then
            BFC:OpenActiveChatCopy()
        end
    elseif arg1 == "history" and arg2 == "clear" then
        if BFC.ClearHistory then
            BFC:ClearHistory()
        elseif _G["NullgatesChatHistory"] then
            wipe(_G["NullgatesChatHistory"])
        end
        print("|cff00c0ffNullgate's Chat:|r Chat and command history buffers cleared.")
    elseif arg1 == "reset" then
        BFC:ResetProfile()
        print("|cff00c0ffNullgate's Chat:|r Profile settings reset to defaults.")
    else
        print("|cff00c0ffNullgate's Chat:|r Commands:")
        print("  |cffffd100/bfchat|r - Open Settings")
        print("  |cffffd100/bfchat copy|r - Copy active chat window text")
        print("  |cffffd100/bfchat history clear|r - Clear stored history")
    end
end

