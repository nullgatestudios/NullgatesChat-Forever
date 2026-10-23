--[[
    Nullgate's Chat - CopyFrame.lua
    Interactive Dialogs: URL Copy Modal & Full Chat Log Copy Dialog
    Dark Slate & Gold Presentation Layer
]]

local addonName, BFC = ...
BFC = BFC or {}

local CopyFrame = {}
BFC.CopyFrame = CopyFrame
_G["NullgatesChatCopyFrame"] = CopyFrame

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

-- Theme Colors: Dark Slate & Gold
local COLORS = {
    bgSlate      = { 0.08, 0.10, 0.13, 0.96 },
    contentBg    = { 0.05, 0.06, 0.08, 0.94 },
    goldBorder   = { 0.82, 0.68, 0.28, 1.00 },
    goldMuted    = { 0.50, 0.42, 0.20, 0.85 },
    goldText     = { 1.00, 0.82, 0.25 },
    whiteText    = { 0.90, 0.92, 0.94 },
    dimText      = { 0.55, 0.58, 0.63 },
}

local WINDOW_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

local INSET_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 12,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

--[[-----------------------------------------------------------------------------
    1. URL Copy Modal Dialog
-------------------------------------------------------------------------------]]
local urlDialog = nil

local function CreateURLDialog()
    if urlDialog then return urlDialog end

    local f = CreateFrame("Frame", "NullgatesChat_URLDialog", UIParent, BACKDROP_TEMPLATE)
    f:SetSize(460, 130)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f:SetBackdrop(WINDOW_BACKDROP)
    f:SetBackdropColor(unpack(COLORS.bgSlate))
    f:SetBackdropBorderColor(unpack(COLORS.goldBorder))

    -- Header Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    title:SetText("|cffffd100Nullgate's Chat|r - Copy Link")

    -- Subtitle / Instructions
    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetTextColor(COLORS.dimText[1], COLORS.dimText[2], COLORS.dimText[3])
    subtitle:SetText("Press |cffffffffCtrl + C|r to copy the link to your clipboard:")

    -- Inset EditBox Container
    local editContainer = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    editContainer:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    editContainer:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    editContainer:SetHeight(28)
    editContainer:SetBackdrop(INSET_BACKDROP)
    editContainer:SetBackdropColor(unpack(COLORS.contentBg))
    editContainer:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local editBox = CreateFrame("EditBox", nil, editContainer)
    editBox:SetPoint("TOPLEFT", editContainer, "TOPLEFT", 6, -2)
    editBox:SetPoint("BOTTOMRIGHT", editContainer, "BOTTOMRIGHT", -6, 2)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    editBox:SetScript("OnEnterPressed", function() f:Hide() end)
    editBox:SetScript("OnMouseUp", function(self)
        self:HighlightText()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        if f:IsShown() then
            self:HighlightText()
        end
    end)
    f.editBox = editBox

    f:SetScript("OnShow", function(self)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end)

    -- Close Button (Top Right 'X')
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Bottom 'Done' Button
    local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    doneBtn:SetSize(80, 22)
    doneBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 10)
    doneBtn:SetText("Done")
    doneBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    urlDialog = f
    return f
end

function CopyFrame:ShowURL(url)
    if not url or url == "" then return end
    local f = CreateURLDialog()
    f.editBox:SetText(url)
    f:Show()
    f.editBox:SetFocus()
    f.editBox:HighlightText()
end

--[[-----------------------------------------------------------------------------
    2. Chat Log Copy Dialog
-------------------------------------------------------------------------------]]
local chatLogDialog = nil

local function CreateChatLogDialog()
    if chatLogDialog then return chatLogDialog end

    local f = CreateFrame("Frame", "NullgatesChat_ChatLogDialog", UIParent, BACKDROP_TEMPLATE)
    f:SetSize(600, 440)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(95)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(420, 280, 900, 700)
    elseif f.SetMinResize then
        f:SetMinResize(420, 280)
        f:SetMaxResize(900, 700)
    end

    f:SetBackdrop(WINDOW_BACKDROP)
    f:SetBackdropColor(unpack(COLORS.bgSlate))
    f:SetBackdropBorderColor(unpack(COLORS.goldBorder))

    -- Header Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText("|cffffd100Nullgate's Chat|r - Chat Log Copy")
    f.title = title

    -- Subtitle
    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetTextColor(COLORS.dimText[1], COLORS.dimText[2], COLORS.dimText[3])
    subtitle:SetText("Highlight and press |cffffffffCtrl + C|r to copy chat messages:")

    -- Inset Box for Text
    local inset = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -54)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 44)
    inset:SetBackdrop(INSET_BACKDROP)
    inset:SetBackdropColor(unpack(COLORS.contentBg))
    inset:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "NullgatesChatLogScrollFrame", inset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 6)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll() or 0
        local step = 36
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, cur - step))
        else
            local maxScroll = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.min(maxScroll, cur + step))
        end
    end)
    f.scrollFrame = scrollFrame

    -- ScrollChild with EditBox
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(520, 320)
    scrollFrame:SetScrollChild(scrollChild)
    f.scrollChild = scrollChild

    local editBox = CreateFrame("EditBox", nil, scrollChild)
    editBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    editBox:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetCountInvisibleLetters(true)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    editBox:SetScript("OnTextChanged", function(self)
        -- Adjust child height dynamically based on content
        local h = math.max(self:GetHeight() + 24, scrollFrame:GetHeight() or 300)
        scrollChild:SetHeight(h)
        if scrollFrame.UpdateScrollChildRect then
            scrollFrame:UpdateScrollChildRect()
        end
    end)
    f.editBox = editBox

    -- Synchronize scroll child width when dialog resizes
    scrollFrame:HookScript("OnSizeChanged", function(self, w, h)
        if w and w > 0 then
            scrollChild:SetWidth(w)
            editBox:SetWidth(w)
            local childH = math.max(editBox:GetHeight() + 24, h or 300)
            scrollChild:SetHeight(childH)
            if self.UpdateScrollChildRect then
                self:UpdateScrollChildRect()
            end
        end
    end)

    -- Close Button ('X')
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Resize Grip
    local resizeGrip = CreateFrame("Button", nil, f)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resizeGrip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    -- Select All Button
    local selectAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(100, 22)
    selectAllBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    -- Done / Close Button
    local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    doneBtn:SetSize(80, 22)
    doneBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 12)
    doneBtn:SetText("Close")
    doneBtn:SetScript("OnClick", function() f:Hide() end)

    -- Status / Line Count
    local countText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("LEFT", selectAllBtn, "RIGHT", 12, 0)
    countText:SetTextColor(COLORS.dimText[1], COLORS.dimText[2], COLORS.dimText[3])
    f.countText = countText

    f:Hide()
    chatLogDialog = f
    return f
end

-- Strip color and hyperlink codes for clean plain-text copying
local function CleanMessageFormatting(str)
    if not str then return "" end
    -- Strip color tags: |cffXXXXXX and |r
    local clean = str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- Strip textures: |T...|t
    clean = clean:gsub("|T.-|t", "")
    -- Strip player links cleanly: |Hplayer:...|h[PlayerName]|h -> PlayerName
    clean = clean:gsub("|Hplayer:.-|h%[(.-)%]|h", "%1")
    -- Strip URL hyperlinks to raw URL for plain-text pasting
    clean = clean:gsub("|Hurl:(.-)|h.-|h", "%1")
    -- Strip other hyperlinks (items, spells, quests, achievements): |H...|h[text]|h -> [text]
    clean = clean:gsub("|H.-|h%[(.-)%]|h", "[%1]")
    clean = clean:gsub("|H.-|h(.-)|h", "%1")
    return clean
end

function CopyFrame:ShowChatLog(chatFrame, textLines)
    local f = CreateChatLogDialog()
    local frameName = (chatFrame and chatFrame.GetName and chatFrame:GetName()) or "Chat"
    local tab = _G[frameName .. "Tab"]
    local tabName = (tab and tab.GetText and tab:GetText()) or frameName

    f.title:SetText(string.format("|cffffd100Nullgate's Chat|r - Copy: |cffffffff%s|r", tabName))

    local formatted = ""
    local lineCount = 0

    if type(textLines) == "table" and #textLines > 0 then
        local cleaned = {}
        for _, line in ipairs(textLines) do
            lineCount = lineCount + 1
            table.insert(cleaned, CleanMessageFormatting(line))
        end
        formatted = table.concat(cleaned, "\n")
    elseif type(textLines) == "string" and textLines ~= "" then
        formatted = CleanMessageFormatting(textLines)
        lineCount = select(2, formatted:gsub("\n", "\n")) + 1
    elseif BFC.GetChatFrameMessages then
        local lines = BFC:GetChatFrameMessages(chatFrame)
        if lines and #lines > 0 then
            local cleaned = {}
            for _, line in ipairs(lines) do
                lineCount = lineCount + 1
                table.insert(cleaned, CleanMessageFormatting(line))
            end
            formatted = table.concat(cleaned, "\n")
        end
    end

    if formatted == "" then
        formatted = "(No recent chat messages found in this tab.)"
        lineCount = 0
    end

    f.editBox:SetText(formatted)
    f.countText:SetText(string.format("%d message lines", lineCount))

    if f.scrollChild and f.scrollFrame then
        local childH = math.max(f.editBox:GetHeight() + 24, f.scrollFrame:GetHeight() or 300)
        f.scrollChild:SetHeight(childH)
        if f.scrollFrame.UpdateScrollChildRect then
            f.scrollFrame:UpdateScrollChildRect()
        end
        f.scrollFrame:SetVerticalScroll(0)
    end

    f:Show()
    f.editBox:SetFocus()
    f.editBox:HighlightText()
end

