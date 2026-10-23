--[[
    Nullgate's Chat - Core.lua
    Gameplay & Event Engine: URL Detection, Universal Class Colors,
    Whisper Popout Routing, Persistent History, EditBox & Clutter Suppression
]]

local addonName, BFC = ...
BFC = LibStub("AceAddon-3.0"):NewAddon(BFC, "NullgatesChat", "AceEvent-3.0", "AceHook-3.0")
_G["NullgatesChatCore"] = BFC

-- Backdrop template compatibility for Retail / Dragonflight / 3.3.5 / Ascension
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

-- Class color hex cache
local CLASS_COLORS = {}
for classToken, color in pairs(RAID_CLASS_COLORS) do
    CLASS_COLORS[classToken] = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

-- Channel name shortening lookup
local CHANNEL_REPLACEMENTS = {
    ["%[(%d+)%.%s*.-%]"]        = "[%1]",
    ["%[Guild%]"]               = "[G]",
    ["%[Party%]"]               = "[P]",
    ["%[Party Leader%]"]        = "[PL]",
    ["%[Raid%]"]                = "[R]",
    ["%[Raid Leader%]"]         = "[RL]",
    ["%[Raid Warning%]"]        = "[RW]",
    ["%[Officer%]"]             = "[O]",
    ["%[Battleground%]"]        = "[BG]",
    ["%[Battleground Leader%]"] = "[BL]",
    ["%[Instance%]"]            = "[I]",
    ["%[Instance Leader%]"]     = "[IL]",
    ["%[Dungeon Guide%]"]       = "[DG]",
}

-- Session in-memory line buffer per frame for copy & export
BFC.sessionHistory = {}
BFC.playerClassCache = {}
BFC.cmdHistory = {}

function BFC:GetCharKey()
    local charName = UnitName("player")
    local realmName = GetRealmName()
    if charName and realmName and charName ~= "" and realmName ~= "" and charName ~= "Unknown" then
        return charName .. " - " .. realmName
    end
    return self.charKey or ((charName or "Unknown") .. " - " .. (realmName or "DefaultRealm"))
end

local function GetAllChatEditBoxes()
    local list = {}
    local seen = {}
    local function addBox(eb)
        if eb and not seen[eb] then
            seen[eb] = true
            table.insert(list, eb)
        end
    end

    addBox(_G["ChatFrameEditBox"])
    if ChatEdit_GetActiveWindow then
        addBox(ChatEdit_GetActiveWindow())
    end

    local numWindows = NUM_CHAT_WINDOWS or 10
    for i = 1, numWindows do
        addBox(_G["ChatFrame" .. i .. "EditBox"])
        local cf = _G["ChatFrame" .. i]
        if cf and cf.editBox then
            addBox(cf.editBox)
        end
    end

    if CHAT_FRAMES then
        for _, name in ipairs(CHAT_FRAMES) do
            addBox(_G[name .. "EditBox"])
            local cf = _G[name]
            if cf and cf.editBox then
                addBox(cf.editBox)
            end
        end
    end

    return list
end

--[[-----------------------------------------------------------------------------
    Lifecycle: OnInitialize & OnEnable
-------------------------------------------------------------------------------]]
function BFC:OnInitialize()
    self:InitDB()
    self:RegisterWithMasterConfig()

    -- Character key for persistent storage
    self.charKey = self:GetCharKey()
    self.cmdHistory = self.cmdHistory or {}

    -- Ensure character storage table exists
    self.historyDB[self.charKey] = self.historyDB[self.charKey] or {
        frames = {},
        editBox = {},
    }
end

function BFC:OnEnable()
    self:SetupWhisperRouting()
    self:SetupClassColoring()
    self:SetupUrlDetection()
    self:SetupChatFrames()
    self:SetupEditBox()
    self:SetupChatHistory()

    if ChatEdit_ActivateChat and not self._hookedActivateChat then
        self._hookedActivateChat = true
        hooksecurefunc("ChatEdit_ActivateChat", function(eb)
            if eb then
                BFC:HookEditBox(eb)
            end
        end)
    end

    if ChatEdit_SendText and not self._hookedSendText then
        self._hookedSendText = true
        hooksecurefunc("ChatEdit_SendText", function(editBox, addHistory)
            if editBox and editBox._bfcPendingText and editBox._bfcPendingText ~= "" then
                BFC:OnCommandSent(editBox._bfcPendingText, editBox)
                editBox._bfcPendingText = nil
            end
        end)
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ADDON_LOADED")
end

function BFC:ADDON_LOADED(event, loadedAddon)
    if loadedAddon == "NullgatesAddonConfig-Forever" or loadedAddon == "NullgatesAddonConfig" or loadedAddon == "NullgatesAddonConfigForever" then
        self:RegisterWithMasterConfig()
    end
end

--[[-----------------------------------------------------------------------------
    Whispers to New Window / Tab by Default
-------------------------------------------------------------------------------]]
function BFC:SetupWhisperRouting()
    local db = self.db or {}
    if SetCVar then
        if db.whisperWindow ~= false then
            -- Native Blizzard CVar: automatically routes whispers to new temporary tabs
            SetCVar("whisperMode", "popout")
        else
            SetCVar("whisperMode", "inline")
        end
    end

    if not self._hookedFlashTab and FCF_FlashTab then
        self._hookedFlashTab = true
        hooksecurefunc("FCF_FlashTab", function(tab)
            local currentDb = BFC.db or {}
            if currentDb.whisperNotifyGlow == false and FCF_StopFlashing then
                FCF_StopFlashing(tab)
            end
        end)
    end
end

--[[-----------------------------------------------------------------------------
    Universal Player Class Coloring
-------------------------------------------------------------------------------]]
function BFC:SetupClassColoring()
    local db = self.db or {}
    if not db.classColorNames then return end

    -- Enable native Blizzard class color flags across all chat types
    if ChatTypeInfo then
        local typesToColor = {
            "SAY", "EMOTE", "YELL", "WHISPER", "WHISPER_INFORM",
            "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
            "GUILD", "OFFICER", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
            "BN_WHISPER", "BN_WHISPER_INFORM",
        }
        for _, t in ipairs(typesToColor) do
            if ChatTypeInfo[t] then
                ChatTypeInfo[t].colorNameByClass = true
            end
        end
        for i = 1, 20 do
            local ch = "CHANNEL" .. i
            if ChatTypeInfo[ch] then
                ChatTypeInfo[ch].colorNameByClass = true
            end
        end
    end

    if not self._rosterEventsRegistered then
        self._rosterEventsRegistered = true
        self:RegisterEvent("FRIENDLIST_UPDATE", "UpdateRosterCache")
        self:RegisterEvent("GUILD_ROSTER_UPDATE", "UpdateRosterCache")
        self:RegisterEvent("CHAT_MSG_SAY", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_YELL", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_PARTY", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_PARTY_LEADER", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_RAID", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_RAID_WARNING", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_GUILD", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_OFFICER", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_WHISPER", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "OnMessageEvent")
        self:RegisterEvent("CHAT_MSG_CHANNEL", "OnMessageEvent")
    end
    self:UpdateRosterCache()
end

function BFC:UpdateRosterCache()
    -- Friends
    local numFriends = GetNumFriends and GetNumFriends() or 0
    for i = 1, numFriends do
        local name, _, class = GetFriendInfo(i)
        if name and class then
            local cleanName = name:match("^(.-)%-") or name
            for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
                if localized == class then self.playerClassCache[cleanName] = token break end
            end
            for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
                if localized == class then self.playerClassCache[cleanName] = token break end
            end
        end
    end

    -- Guild
    if IsInGuild and IsInGuild() and GetNumGuildMembers then
        local numGuild = GetNumGuildMembers() or 0
        for i = 1, numGuild do
            local name, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if name and classFileName then
                local cleanName = name:match("^(.-)%-") or name
                self.playerClassCache[cleanName] = classFileName
            end
        end
    end
end

function BFC:OnMessageEvent(event, msg, sender, _, _, _, _, _, _, _, _, guid)
    if sender and guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken then
            local cleanName = sender:match("^(.-)%-") or sender
            self.playerClassCache[cleanName] = classToken
        end
    end
end

-- Helper: Retrieve player class color hex
function BFC:GetPlayerClassHex(name, guid)
    if guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken and CLASS_COLORS[classToken] then
            if name and name ~= "" then
                local cleanName = name:match("^(.-)%-") or name
                self.playerClassCache[cleanName] = classToken
            end
            return CLASS_COLORS[classToken]
        end
    end

    if not name or name == "" then return nil end
    local cleanName = name:match("^(.-)%-") or name

    -- Check cache
    if self.playerClassCache[cleanName] and CLASS_COLORS[self.playerClassCache[cleanName]] then
        return CLASS_COLORS[self.playerClassCache[cleanName]]
    end

    -- Check player
    if UnitName("player") == cleanName then
        local _, classToken = UnitClass("player")
        if classToken and CLASS_COLORS[classToken] then
            self.playerClassCache[cleanName] = classToken
            return CLASS_COLORS[classToken]
        end
    end

    -- Check party/raid units
    for i = 1, GetNumGroupMembers() or 0 do
        local unit = (IsInRaid() and "raid" or "party") .. i
        if UnitName(unit) == cleanName then
            local _, classToken = UnitClass(unit)
            if classToken and CLASS_COLORS[classToken] then
                self.playerClassCache[cleanName] = classToken
                return CLASS_COLORS[classToken]
            end
        end
    end

    return nil
end

--[[-----------------------------------------------------------------------------
    URL Detection & Clickable Hyperlinks
-------------------------------------------------------------------------------]]
local COMMON_TLDS = {
    ["com"] = true, ["org"] = true, ["net"] = true, ["edu"] = true, ["gov"] = true,
    ["io"] = true, ["gg"] = true, ["tv"] = true, ["me"] = true, ["app"] = true,
    ["dev"] = true, ["co"] = true, ["uk"] = true, ["de"] = true, ["ca"] = true,
    ["ru"] = true, ["fr"] = true, ["eu"] = true, ["info"] = true, ["biz"] = true,
}

local function IsURL(token)
    if not token or token == "" then return false end
    if token:find("@") then return false end -- Exclude emails
    if token:find("^https?://") or token:find("^ftp://") then
        return true
    end
    if token:find("^www%.[%w_%-%.]+%.%a%a+") then
        return true
    end
    if token:find("^discord%.gg/%S+") or token:find("^discordapp%.com/invite/%S+") then
        return true
    end
    local host = token:match("^([%w_%-%.]+)/.*$") or token
    local domain, tld = host:match("^([%w_%-%.]+)%.(%a+)$")
    if domain and tld then
        if COMMON_TLDS[tld:lower()] then
            return true
        end
    end
    return false
end

local function StripPunctuation(token)
    local prefix = ""
    local suffix = ""
    
    while #token > 0 do
        local c = token:sub(1, 1)
        if c == "(" or c == "[" or c == "{" or c == '"' or c == "'" or c == "<" then
            prefix = prefix .. c
            token = token:sub(2)
        else
            break
        end
    end
    
    while #token > 0 do
        local c = token:sub(-1, -1)
        if c == ")" or c == "]" or c == "}" or c == ">" or c == '"' or c == "'"
           or c == "!" or c == "?" or c == "," or c == "." or c == ";" or c == ":" then
            if c == ")" and token:find("%(") then
                break
            end
            if c == "]" and token:find("%[") then
                break
            end
            suffix = c .. suffix
            token = token:sub(1, -2)
        else
            break
        end
    end
    
    return prefix, token, suffix
end

function BFC:GetUrlColorHex()
    local db = self.db or {}
    local col = db.urlColor or { r = 0.20, g = 0.85, b = 1.00 }
    return string.format("%02x%02x%02x", math.floor((col.r or 0.20) * 255 + 0.5), math.floor((col.g or 0.85) * 255 + 0.5), math.floor((col.b or 1.00) * 255 + 0.5))
end

function BFC:FormatUrlsInText(message)
    if not message or message == "" then return message end

    -- Step 1: Preserve existing hyperlinks (|H...|h...|h)
    local links = {}
    local preserved = message:gsub("(|H.-|h.-|h)", function(link)
        local idx = #links + 1
        links[idx] = link
        return string.format("\001BFC_LINK_%d\002", idx)
    end)

    local urlHex = self:GetUrlColorHex()

    -- Step 2: Scan whitespace-delimited tokens
    local processed = preserved:gsub("(%S+)", function(word)
        if word:find("^\001BFC_LINK_") then
            return word
        end

        local leadColor, coreWord = word:match("^(|c%x%x%x%x%x%x%x%x)(.*)$")
        if not leadColor then
            coreWord = word
            leadColor = ""
        end

        local trailR = ""
        if coreWord:sub(-2) == "|r" then
            trailR = "|r"
            coreWord = coreWord:sub(1, -3)
        end

        local prefix, token, suffix = StripPunctuation(coreWord)
        if token and IsURL(token) then
            local formatted = string.format("|cff%s|Hurl:%s|h[%s]|h|r", urlHex, token, token)
            return leadColor .. prefix .. formatted .. suffix .. trailR
        end

        return word
    end)

    -- Step 3: Restore preserved hyperlinks
    local restored = processed:gsub("\001BFC_LINK_(%d+)\002", function(idx)
        return links[tonumber(idx)] or ""
    end)

    return restored
end

function BFC:ProcessMessageText(message, sender, guid)
    if type(message) ~= "string" or message == "" then return message end
    local db = self.db or {}

    -- 1. URL Replacement
    if db.enableUrlLinks then
        message = self:FormatUrlsInText(message)
    end

    -- 2. Channel Name Shortening
    if db.shortChannelNames then
        for pat, repl in pairs(CHANNEL_REPLACEMENTS) do
            message = message:gsub(pat, repl)
        end
    end

    -- 3. Universal Player Class Coloring in Hyperlinks
    if db.classColorNames then
        message = message:gsub("(|c%x%x%x%x%x%x%x%x)(|Hplayer:([^:]+).-|h%[.-%]|h|r)", function(color, link, name)
            local cleanName = name:match("^(.-)%-") or name
            local classHex = BFC:GetPlayerClassHex(cleanName)
            if classHex then
                return "|cff" .. classHex .. link
            end
            return color .. link
        end)
        message = message:gsub("([^|])(|Hplayer:([^:]+).-|h%[.-%]|h)", function(prefix, link, name)
            local cleanName = name:match("^(.-)%-") or name
            local classHex = BFC:GetPlayerClassHex(cleanName)
            if classHex then
                return prefix .. "|cff" .. classHex .. link .. "|r"
            end
            return prefix .. link
        end)
        message = message:gsub("^(|Hplayer:([^:]+).-|h%[.-%]|h)", function(link, name)
            local cleanName = name:match("^(.-)%-") or name
            local classHex = BFC:GetPlayerClassHex(cleanName)
            if classHex then
                return "|cff" .. classHex .. link .. "|r"
            end
            return link
        end)
    end

    -- 4. Timestamps
    if db.showTimestamps and not message:find("^|c%x%x%x%x%x%x%x%x%[") then
        local tFormat = db.timestampFormat or "%H:%M"
        local tColor = db.timestampColor or { r = 0.55, g = 0.58, b = 0.63 }
        local hex = string.format("%02x%02x%02x", tColor.r * 255, tColor.g * 255, tColor.b * 255)
        local stamp = date(tFormat)
        if stamp and stamp ~= "" then
            message = string.format("|cff%s[%s]|r %s", hex, stamp, message)
        end
    end

    return message
end

function BFC:SetupUrlDetection()
    -- Hook SetItemRef to catch "url:" hyperlinks
    local orig_SetItemRef = SetItemRef
    SetItemRef = function(link, text, button, chatFrame)
        if link and link:sub(1, 4) == "url:" then
            local url = link:sub(5)
            if IsShiftKeyDown() then
                local editBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
                if not editBox and LAST_ACTIVE_CHAT_EDIT_BOX and LAST_ACTIVE_CHAT_EDIT_BOX:IsShown() then
                    editBox = LAST_ACTIVE_CHAT_EDIT_BOX
                end
                if editBox and editBox:IsShown() then
                    editBox:Insert(url)
                    return
                end
            end
            if BFC.CopyFrame and BFC.CopyFrame.ShowURL then
                BFC.CopyFrame:ShowURL(url)
            end
            return
        end
        return orig_SetItemRef(link, text, button, chatFrame)
    end

    if ChatFrame_OnHyperlinkShow and not self._hookedHyperlinkShow then
        hooksecurefunc("ChatFrame_OnHyperlinkShow", function(chatFrame, link, text, button)
            if link and link:sub(1, 4) == "url:" then
                local url = link:sub(5)
                if not IsShiftKeyDown() and BFC.CopyFrame and BFC.CopyFrame.ShowURL then
                    local urlDlg = _G["NullgatesChat_URLDialog"]
                    if not (urlDlg and urlDlg:IsShown()) then
                        BFC.CopyFrame:ShowURL(url)
                    end
                end
            end
        end)
        self._hookedHyperlinkShow = true
    end
end

--[[-----------------------------------------------------------------------------
    ChatFrame Modernization: MouseWheel, Buttons, Typography & Copy Button
-------------------------------------------------------------------------------]]
local copyButtons = {}

local function CreateCopyButton(chatFrame)
    local frameName = chatFrame:GetName()
    if not frameName then return end

    local btn = copyButtons[frameName]
    if not btn then
        btn = CreateFrame("Button", frameName .. "NullgateCopyBtn", chatFrame)
        btn:SetSize(16, 16)
        btn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -2, -2)
        btn:SetAlpha(0.35)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(btn)
        icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        btn.icon = icon

        btn:SetScript("OnEnter", function(self)
            self:SetAlpha(1.0)
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("|cffffd100Copy Chat Log|r", 1, 1, 1)
            GameTooltip:AddLine("Click to open plain-text copy window for this chat tab.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetAlpha(0.35)
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", function()
            if BFC.CopyFrame and BFC.CopyFrame.ShowChatLog then
                BFC.CopyFrame:ShowChatLog(chatFrame)
            end
        end)

        copyButtons[frameName] = btn
    end

    local db = BFC.db or {}
    if db.showCopyButton == false then
        btn:Hide()
    else
        btn:Show()
    end
end

function BFC:InitChatFrame(cf)
    if not cf then return end
    local fName = cf:GetName()
    if not fName then return end

    local db = self.db or {}

    -- Unclamp frame to allow flush screen placement
    cf:SetClampedToScreen(not db.unclampFromScreen)

    -- Mousewheel scrolling (Smooth + Shift jump + Ctrl jump)
    if db.enableMouseWheel then
        cf:EnableMouseWheel(true)
        if not cf._bfcWheelHooked then
            cf._bfcWheelHooked = true
            cf:SetScript("OnMouseWheel", function(self, delta)
                if delta > 0 then
                    if IsShiftKeyDown() then
                        self:ScrollToTop()
                    elseif IsControlKeyDown() then
                        for i = 1, 5 do self:ScrollUp() end
                    else
                        self:ScrollUp()
                    end
                elseif delta < 0 then
                    if IsShiftKeyDown() then
                        self:ScrollToBottom()
                    elseif IsControlKeyDown() then
                        for i = 1, 5 do self:ScrollDown() end
                    else
                        self:ScrollDown()
                    end
                end
            end)
        end
    else
        cf:EnableMouseWheel(false)
    end

    -- Hide scroll up/down/bottom buttons if requested
    local bottomBtn = _G[fName .. "BottomButton"]
    local upBtn = _G[fName .. "UpButton"]
    local downBtn = _G[fName .. "DownButton"]

    if db.hideScrollButtons then
        if bottomBtn then
            bottomBtn:Hide()
            if not bottomBtn._bfcHooked then
                bottomBtn._bfcHooked = true
                bottomBtn:HookScript("OnShow", bottomBtn.Hide)
            end
        end
        if upBtn then
            upBtn:Hide()
            if not upBtn._bfcHooked then
                upBtn._bfcHooked = true
                upBtn:HookScript("OnShow", upBtn.Hide)
            end
        end
        if downBtn then
            downBtn:Hide()
            if not downBtn._bfcHooked then
                downBtn._bfcHooked = true
                downBtn:HookScript("OnShow", downBtn.Hide)
            end
        end
    else
        if bottomBtn then bottomBtn:Show() end
        if upBtn then upBtn:Show() end
        if downBtn then downBtn:Show() end
    end

    -- Custom Backdrop
    self:ApplyFrameBackdrop(cf)

    -- Typography
    self:ApplyFrameTypography(cf)

    -- In-memory session tracking & Hook AddMessage
    self.sessionHistory[fName] = self.sessionHistory[fName] or {}

    if not cf._bfcAddMessageHooked then
        local origAddMessage = cf.AddMessage
        cf.AddMessage = function(frame, msg, r, g, b, id, ...)
            -- Run text formatting pipeline
            local processed = BFC:ProcessMessageText(msg)

            -- Record to session memory
            table.insert(BFC.sessionHistory[fName], processed)
            if #BFC.sessionHistory[fName] > 500 then
                table.remove(BFC.sessionHistory[fName], 1)
            end

            -- Record to persistent SavedVariables if enabled and not currently restoring
            if not BFC.isRestoringHistory and BFC.db and BFC.db.enableChatHistory then
                local charStore = BFC.historyDB[BFC.charKey]
                if charStore and charStore.frames then
                    charStore.frames[fName] = charStore.frames[fName] or {}
                    local frameList = charStore.frames[fName]
                    table.insert(frameList, { text = processed, r = r, g = g, b = b, time = time() })
                    local maxLines = BFC.db.chatHistoryLines or 200
                    while #frameList > maxLines do
                        table.remove(frameList, 1)
                    end
                end
            end

            return origAddMessage(frame, processed, r, g, b, id, ...)
        end
        cf._bfcAddMessageHooked = true
    end

    -- Add/Update Copy Button
    CreateCopyButton(cf)

    -- Position edit box
    local eb = _G[fName .. "EditBox"] or _G["ChatFrameEditBox"]
    if eb then
        self:PositionEditBox(eb, cf)
    end
end

function BFC:SetupChatFrames()
    local db = self.db or {}

    -- Suppress Blizzard Intrusive Buttons
    if db.hideChatButtons then
        if ChatFrameMenuButton then
            ChatFrameMenuButton:Hide()
            if not ChatFrameMenuButton._bfcHooked then
                ChatFrameMenuButton._bfcHooked = true
                ChatFrameMenuButton:HookScript("OnShow", ChatFrameMenuButton.Hide)
            end
        end
        if ChatFrameChannelButton then
            ChatFrameChannelButton:Hide()
            if not ChatFrameChannelButton._bfcHooked then
                ChatFrameChannelButton._bfcHooked = true
                ChatFrameChannelButton:HookScript("OnShow", ChatFrameChannelButton.Hide)
            end
        end
    else
        if ChatFrameMenuButton then ChatFrameMenuButton:Show() end
        if ChatFrameChannelButton then ChatFrameChannelButton:Show() end
    end

    -- Initialize all registered chat frames
    if CHAT_FRAMES and #CHAT_FRAMES > 0 then
        for _, name in ipairs(CHAT_FRAMES) do
            local cf = _G[name]
            if cf then
                self:InitChatFrame(cf)
            end
        end
    else
        local numWindows = NUM_CHAT_WINDOWS or 7
        for i = 1, numWindows do
            local cf = _G["ChatFrame" .. i]
            if cf then
                self:InitChatFrame(cf)
            end
        end
    end

    -- Hook temporary and newly created chat frames
    if FCF_OpenTemporaryWindow and not self._hookedOpenTemp then
        hooksecurefunc("FCF_OpenTemporaryWindow", function(chatType, chatTarget)
            for _, name in ipairs(CHAT_FRAMES or {}) do
                local cf = _G[name]
                if cf then
                    BFC:InitChatFrame(cf)
                end
            end
            BFC:SetupEditBox()
        end)
        self._hookedOpenTemp = true
    end

    if FCF_OpenNewWindow and not self._hookedOpenNew then
        hooksecurefunc("FCF_OpenNewWindow", function(name)
            for _, frameName in ipairs(CHAT_FRAMES or {}) do
                local cf = _G[frameName]
                if cf then
                    BFC:InitChatFrame(cf)
                end
            end
            BFC:SetupEditBox()
        end)
        self._hookedOpenNew = true
    end
end

function BFC:ApplyFrameBackdrop(chatFrame)
    if not chatFrame then return end
    local fName = chatFrame:GetName()
    if not fName then return end

    local db = self.db or {}

    if db.enableCustomBackdrop then
        if not chatFrame.nullgateBackdrop then
            local bd = CreateFrame("Frame", fName .. "NullgateBackdrop", chatFrame, BACKDROP_TEMPLATE)
            if not bd.SetBackdrop and BackdropTemplateMixin then
                Mixin(bd, BackdropTemplateMixin)
                if bd.OnBackdropLoaded then bd:OnBackdropLoaded() end
            end
            bd:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -6, 6)
            bd:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", 6, -6)
            bd:SetFrameLevel(math.max(0, chatFrame:GetFrameLevel() - 1))
            if bd.SetBackdrop then
                bd:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true,
                    tileSize = 12,
                    edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 }
                })
            end
            chatFrame.nullgateBackdrop = bd
        end

        local th = db.theme or {}
        local bgR = th.bgR or 0.08
        local bgG = th.bgG or 0.10
        local bgB = th.bgB or 0.13
        local bgA = db.backdropAlpha or 0.65
        local bR = th.borderR or 0.82
        local bG = th.borderG or 0.68
        local bB = th.borderB or 0.28
        local bA = th.borderA or 0.85

        if chatFrame.nullgateBackdrop.SetBackdropColor then
            chatFrame.nullgateBackdrop:SetBackdropColor(bgR, bgG, bgB, bgA)
        end
        if chatFrame.nullgateBackdrop.SetBackdropBorderColor then
            chatFrame.nullgateBackdrop:SetBackdropBorderColor(bR, bG, bB, bA)
        end
        chatFrame.nullgateBackdrop:Show()
    else
        if chatFrame.nullgateBackdrop then
            chatFrame.nullgateBackdrop:Hide()
        end
    end
end

function BFC:ApplyFrameTypography(chatFrame)
    if not chatFrame then return end
    local db = self.db or {}
    local fontName = db.font or "Nata Sans Regular"
    local fontSize = db.fontSize or 12
    local fontOutline = db.fontOutline or "OUTLINE"
    if fontOutline == "NONE" or fontOutline == "None" then fontOutline = "" end
    local fontPath = self.FetchFont and self:FetchFont(fontName) or "Fonts\\FRIZQT__.TTF"

    chatFrame:SetFont(fontPath, fontSize, fontOutline)

    local tab = _G[chatFrame:GetName() .. "Tab"]
    if tab and tab.GetFontString and tab:GetFontString() then
        local tabFs = tab:GetFontString()
        tabFs:SetFont(fontPath, math.max(10, fontSize - 1), fontOutline)
    end
end

function BFC:ApplyEditBoxTypography(editBox)
    if not editBox then return end
    local db = self.db or {}
    local fontName = db.font or "Nata Sans Regular"
    local fontSize = db.fontSize or 12
    local fontOutline = db.fontOutline or "OUTLINE"
    if fontOutline == "NONE" or fontOutline == "None" then fontOutline = "" end
    local fontPath = self.FetchFont and self:FetchFont(fontName) or "Fonts\\FRIZQT__.TTF"

    if editBox.SetFont then
        editBox:SetFont(fontPath, fontSize, fontOutline)
    end
end

--[[-----------------------------------------------------------------------------
    Persistent Chat History & Session Divider
-------------------------------------------------------------------------------]]
function BFC:SetupChatHistory()
    -- History is loaded once on PLAYER_ENTERING_WORLD
end

function BFC:ClearHistory()
    local charKey = self:GetCharKey()
    if self.historyDB and self.historyDB[charKey] then
        self.historyDB[charKey].frames = {}
        self.historyDB[charKey].editBox = {}
    end
    wipe(self.sessionHistory)
    self.cmdHistory = {}

    local allBoxes = GetAllChatEditBoxes()
    for _, eb in ipairs(allBoxes) do
        eb._bfcHistoryIndex = nil
        eb._bfcHistoryDraft = nil
        eb._bfcPendingText = nil
        if eb.ClearHistory then
            eb:ClearHistory()
        end
    end
end

function BFC:OnCommandSent(text, editBox)
    if not text or text == "" then return end
    local db = self.db or {}
    if not db.enableEditBoxHistory then return end

    -- Ignore passwords/secrets
    local lower = text:lower()
    if lower:find("^/pass") or lower:find("^/secret") then
        return
    end

    local charKey = self:GetCharKey()
    local charStore = self.historyDB and self.historyDB[charKey]
    if charStore then
        charStore.editBox = charStore.editBox or {}
        local list = charStore.editBox
        if #list == 0 or list[#list] ~= text then
            table.insert(list, text)
            local maxLines = db.editBoxHistoryLines or 50
            while #list > maxLines do
                table.remove(list, 1)
            end
        end
    end

    -- Update session command history
    self.cmdHistory = self.cmdHistory or {}
    if #self.cmdHistory == 0 or self.cmdHistory[#self.cmdHistory] ~= text then
        table.insert(self.cmdHistory, text)
        local maxLines = db.editBoxHistoryLines or 50
        while #self.cmdHistory > maxLines do
            table.remove(self.cmdHistory, 1)
        end
    end

    -- Push to native Blizzard C++ history lines on all chat edit boxes
    local allBoxes = GetAllChatEditBoxes()
    for _, box in ipairs(allBoxes) do
        if box.AddHistoryLine then
            box:AddHistoryLine(text)
        end
    end
end

function BFC:NavigateEditBoxHistory(editBox, key)
    local db = self.db or {}
    if not db.enableEditBoxHistory then return end

    local history = self.cmdHistory
    if not history or #history == 0 then
        local charKey = self:GetCharKey()
        local charStore = self.historyDB and self.historyDB[charKey]
        if charStore and charStore.editBox and #charStore.editBox > 0 then
            self.cmdHistory = {}
            for _, line in ipairs(charStore.editBox) do
                table.insert(self.cmdHistory, line)
            end
            history = self.cmdHistory
        end
    end
    if not history or #history == 0 then return end

    if key == "UP" then
        if not editBox._bfcHistoryIndex then
            editBox._bfcHistoryDraft = editBox:GetText() or ""
            editBox._bfcHistoryIndex = #history
        else
            editBox._bfcHistoryIndex = editBox._bfcHistoryIndex - 1
            if editBox._bfcHistoryIndex < 1 then
                editBox._bfcHistoryIndex = 1
            end
        end

        local text = history[editBox._bfcHistoryIndex]
        if text then
            editBox:SetText(text)
            editBox:SetCursorPosition(string.len(text))
            editBox._bfcPendingText = text
        end
    elseif key == "DOWN" then
        if not editBox._bfcHistoryIndex then
            return
        end

        editBox._bfcHistoryIndex = editBox._bfcHistoryIndex + 1
        if editBox._bfcHistoryIndex > #history then
            local draft = editBox._bfcHistoryDraft or ""
            editBox:SetText(draft)
            editBox:SetCursorPosition(string.len(draft))
            editBox._bfcPendingText = draft
            editBox._bfcHistoryIndex = nil
            editBox._bfcHistoryDraft = nil
        else
            local text = history[editBox._bfcHistoryIndex]
            if text then
                editBox:SetText(text)
                editBox:SetCursorPosition(string.len(text))
                editBox._bfcPendingText = text
            end
        end
    end
end

function BFC:RestoreEditBoxHistory()
    local db = self.db or {}
    if not db.enableEditBoxHistory then return end

    local charKey = self:GetCharKey()
    local charStore = self.historyDB and self.historyDB[charKey]
    if not (charStore and charStore.editBox) then return end

    local list = charStore.editBox
    if #list == 0 then return end

    -- Seed in-memory session history if not already populated
    self.cmdHistory = self.cmdHistory or {}
    if #self.cmdHistory == 0 then
        for _, line in ipairs(list) do
            table.insert(self.cmdHistory, line)
        end
    end

    local maxLines = db.editBoxHistoryLines or 50
    local allBoxes = GetAllChatEditBoxes()
    for _, eb in ipairs(allBoxes) do
        if eb.SetHistoryLines then
            eb:SetHistoryLines(math.max(#list + 20, maxLines))
        end
        if eb.SetAltArrowKeyMode then
            eb:SetAltArrowKeyMode(false)
        end
        if eb.AddHistoryLine then
            for _, line in ipairs(list) do
                eb:AddHistoryLine(line)
            end
        end
    end
end

function BFC:PLAYER_ENTERING_WORLD()
    local realKey = self:GetCharKey()
    if realKey ~= "Unknown - DefaultRealm" then
        if self.charKey and self.charKey ~= realKey and self.historyDB[self.charKey] then
            if not self.historyDB[realKey] then
                self.historyDB[realKey] = self.historyDB[self.charKey]
            end
            if self.charKey == "Unknown - DefaultRealm" then
                self.historyDB["Unknown - DefaultRealm"] = nil
            end
        end
        self.charKey = realKey
        self.historyDB[self.charKey] = self.historyDB[self.charKey] or {
            frames = {},
            editBox = {},
        }
    end

    -- Re-apply EditBox hooks and arrow mode for all active edit boxes
    self:SetupEditBox()
    self:SetupWhisperRouting()

    if self.hasRestoredHistory then return end
    self.hasRestoredHistory = true

    local db = self.db or {}

    -- 1. Restore Chat Message History
    if db.enableChatHistory then
        local charStore = self.historyDB and self.historyDB[self.charKey]
        if charStore and charStore.frames then
            self.isRestoringHistory = true
            local numWindows = NUM_CHAT_WINDOWS or 7

            for i = 1, numWindows do
                local cf = _G["ChatFrame" .. i]
                if cf then
                    local fName = cf:GetName()
                    local savedLines = charStore.frames[fName]
                    if savedLines and #savedLines > 0 then
                        -- Print session divider
                        if db.showSessionDivider then
                            cf:AddMessage("|cff666666------------- |cffffd100Previous Session|r |cff666666-------------|r", 0.5, 0.5, 0.5)
                        end
                        for _, entry in ipairs(savedLines) do
                            cf:AddMessage(entry.text, entry.r or 1, entry.g or 1, entry.b or 1)
                        end
                    end
                end
            end

            self.isRestoringHistory = false
        end
    end

    -- 2. Restore EditBox Command History
    self:RestoreEditBoxHistory()
end

-- Public extraction helper for CopyFrame
function BFC:GetChatFrameMessages(chatFrame)
    local fName = chatFrame and chatFrame.GetName and chatFrame:GetName()
    if not fName then return {} end

    if self.sessionHistory[fName] and #self.sessionHistory[fName] > 0 then
        return self.sessionHistory[fName]
    end

    -- Fallback to persistent SavedVariables history if session is empty
    if self.historyDB and self.charKey and self.historyDB[self.charKey] then
        local frames = self.historyDB[self.charKey].frames
        if frames and frames[fName] and #frames[fName] > 0 then
            local lines = {}
            for _, entry in ipairs(frames[fName]) do
                table.insert(lines, entry.text)
            end
            return lines
        end
    end

    return {}
end

-- Open copy dialog for active/selected chat frame
function BFC:OpenActiveChatCopy()
    local active = SELECTED_CHAT_FRAME or ChatFrame1
    if self.CopyFrame and self.CopyFrame.ShowChatLog then
        self.CopyFrame:ShowChatLog(active)
    end
end

--[[-----------------------------------------------------------------------------
    EditBox Modernization: Docking, Sticky Channels & Skinning
-------------------------------------------------------------------------------]]
local function SkinEditBox(editBox)
    if not editBox then return end
    local name = editBox:GetName()
    if not name then return end

    local db = BFC.db or {}

    -- Handle default Blizzard textures
    local left = _G[name .. "Left"]
    local right = _G[name .. "Right"]
    local mid = _G[name .. "Mid"]

    if db.editBoxBackdrop ~= false then
        if left then left:SetAlpha(0) end
        if right then right:SetAlpha(0) end
        if mid then mid:SetAlpha(0) end
    else
        if left then left:SetAlpha(1) end
        if right then right:SetAlpha(1) end
        if mid then mid:SetAlpha(1) end
        if editBox.nullgateBackdrop then
            editBox.nullgateBackdrop:Hide()
        end
        return
    end

    if not editBox.nullgateBackdrop then
        local bd = CreateFrame("Frame", nil, editBox, BACKDROP_TEMPLATE)
        if not bd.SetBackdrop and BackdropTemplateMixin then
            Mixin(bd, BackdropTemplateMixin)
            if bd.OnBackdropLoaded then bd:OnBackdropLoaded() end
        end
        bd:SetAllPoints(editBox)
        bd:SetFrameLevel(math.max(0, editBox:GetFrameLevel() - 1))
        if bd.SetBackdrop then
            bd:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 12,
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
        end
        if bd.SetBackdropColor then
            bd:SetBackdropColor(0.08, 0.10, 0.13, 0.94)
        end
        if bd.SetBackdropBorderColor then
            bd:SetBackdropBorderColor(0.82, 0.68, 0.28, 0.85)
        end
        editBox.nullgateBackdrop = bd

        editBox:SetTextInsets(8, 8, 0, 0)

        editBox:HookScript("OnEditFocusGained", function(self)
            if self.nullgateBackdrop and self.nullgateBackdrop.SetBackdropBorderColor then
                self.nullgateBackdrop:SetBackdropBorderColor(1.00, 0.82, 0.25, 1.00)
            end
        end)
        editBox:HookScript("OnEditFocusLost", function(self)
            if self.nullgateBackdrop and self.nullgateBackdrop.SetBackdropBorderColor then
                self.nullgateBackdrop:SetBackdropBorderColor(0.50, 0.42, 0.20, 0.85)
            end
        end)
    end

    editBox.nullgateBackdrop:Show()
    BFC:ApplyEditBoxTypography(editBox)
end

function BFC:PositionEditBox(editBox, chatFrame)
    local db = self.db or {}
    if not editBox then return end
    chatFrame = chatFrame or editBox.chatFrame or SELECTED_CHAT_FRAME or ChatFrame1
    if not chatFrame then return end

    editBox:ClearAllPoints()
    if db.editBoxPosition == "TOP" then
        editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -5, 26)
        editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 5, 26)
    else
        -- Standard BOTTOM docking
        editBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -5, -8)
        editBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 5, -8)
    end
end

function BFC:HookEditBox(eb)
    if not eb or eb._bfcHooked then return end

    local maxHistory = self.db and self.db.editBoxHistoryLines or 50
    if eb.SetHistoryLines then
        eb:SetHistoryLines(maxHistory)
    end
    if eb.SetAltArrowKeyMode then
        eb:SetAltArrowKeyMode(false)
    end

    -- Re-apply position and key mode when edit box shows
    eb:HookScript("OnShow", function(self)
        local cf = self.chatFrame or SELECTED_CHAT_FRAME or ChatFrame1
        BFC:PositionEditBox(self, cf)
        if self.SetAltArrowKeyMode then
            self:SetAltArrowKeyMode(false)
        end
    end)

    -- Track typed text so that it is never lost even if cleared before OnEnterPressed hook
    eb:HookScript("OnTextChanged", function(self, userInput)
        local text = self:GetText()
        if text and text ~= "" then
            self._bfcPendingText = text
        end
    end)

    -- Intercept OnArrowPressed for UP and DOWN arrows (OnKeyDown does not receive arrows in EditBox!)
    local orig_OnArrowPressed = eb:GetScript("OnArrowPressed")
    eb:SetScript("OnArrowPressed", function(self, key)
        if (key == "UP" or key == "DOWN") and not IsAltKeyDown() then
            BFC:NavigateEditBoxHistory(self, key)
            return
        end
        if orig_OnArrowPressed then
            orig_OnArrowPressed(self, key)
        elseif ChatEdit_OnArrowPressed then
            ChatEdit_OnArrowPressed(self, key)
        end
    end)

    -- Intercept OnEnterPressed: Record command into history BEFORE Blizzard clears the editbox!
    local orig_OnEnterPressed = eb:GetScript("OnEnterPressed")
    eb:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if not text or text == "" then
            text = self._bfcPendingText
        end
        if text and text ~= "" then
            BFC:OnCommandSent(text, self)
        end
        self._bfcPendingText = nil
        self._bfcHistoryIndex = nil
        self._bfcHistoryDraft = nil
        if orig_OnEnterPressed then
            orig_OnEnterPressed(self)
        elseif ChatEdit_OnEnterPressed then
            ChatEdit_OnEnterPressed(self)
        end
    end)

    -- Reset navigation cursor when edit box closes or loses focus
    eb:HookScript("OnEscapePressed", function(self)
        self._bfcPendingText = nil
        self._bfcHistoryIndex = nil
        self._bfcHistoryDraft = nil
    end)
    eb:HookScript("OnEditFocusLost", function(self)
        self._bfcHistoryIndex = nil
        self._bfcHistoryDraft = nil
    end)

    eb._bfcHooked = true
end

function BFC:SetupEditBox()
    local db = self.db or {}

    -- Sticky Channels Configuration
    local stickyVal = (db.stickyChannels ~= false) and 1 or 0
    if ChatTypeInfo then
        local stickyList = { "SAY", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "CHANNEL" }
        for _, t in ipairs(stickyList) do
            if ChatTypeInfo[t] then
                ChatTypeInfo[t].sticky = stickyVal
            end
        end
    end

    local allBoxes = GetAllChatEditBoxes()
    for _, eb in ipairs(allBoxes) do
        local parentCf = eb.chatFrame or SELECTED_CHAT_FRAME or ChatFrame1
        self:PositionEditBox(eb, parentCf)
        SkinEditBox(eb)
        self:HookEditBox(eb)
    end
end

--[[-----------------------------------------------------------------------------
    Live Settings Application
-------------------------------------------------------------------------------]]
function BFC:ApplySettings()
    self:SetupWhisperRouting()
    self:SetupClassColoring()
    self:SetupChatFrames()
    self:SetupEditBox()

    local allBoxes = GetAllChatEditBoxes()
    for _, eb in ipairs(allBoxes) do
        self:ApplyEditBoxTypography(eb)
    end
end

-- ---------------------------------------------------------------------------
-- Pre-rebrand version still installed (e.g. a copied Interface folder) would run twice
-- ---------------------------------------------------------------------------
do
    local OLD_ADDON = "BleakfibersChat-Forever"
    local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local DisableAddOn = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn

    StaticPopupDialogs["NULLGATES_CHAT_OLD_ADDON"] = {
        text = "Bleakfiber's Chat is now Nullgate's Chat, and the old version is still installed. Running both loads it twice. Disable the old one now, then delete the BleakfibersChat-Forever folder from Interface\\AddOns.",
        button1 = "Disable and Reload",
        button2 = CANCEL,
        OnAccept = function()
            DisableAddOn(OLD_ADDON)
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local guard = CreateFrame("Frame")
    guard:RegisterEvent("PLAYER_LOGIN")
    guard:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        C_Timer.After(4, function()
            if IsAddOnLoaded and IsAddOnLoaded(OLD_ADDON) then
                StaticPopup_Show("NULLGATES_CHAT_OLD_ADDON")
            end
        end)
    end)
end
