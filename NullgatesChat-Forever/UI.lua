--[[
    Nullgate's Chat - UI.lua
    Presentation Layer: Dark Slate & Gold Theme, Widget Factory,
    Modular Tabbed Options Panel, Responsive Reflow & Standalone Fallback Window
]]

local addonName, BFC = ...
BFC = BFC or {}

local ADDON_NAME = "NullgatesChat"
local FULL_TITLE = "Nullgate's Chat"

local UI = {}
BFC.UI = UI
_G["NullgatesChatUI"] = UI

-- Theme Colors: Dark Slate & Gold
local COLORS = {
    bgSlate      = { 0.08, 0.10, 0.13, 0.96 },
    contentBg    = { 0.05, 0.06, 0.08, 0.94 },
    sidebarBg    = { 0.06, 0.07, 0.09, 0.92 },
    goldBorder   = { 0.82, 0.68, 0.28, 1.00 },
    goldMuted    = { 0.50, 0.42, 0.20, 0.85 },
    goldText     = { 1.00, 0.82, 0.25 },
    whiteText    = { 0.90, 0.92, 0.94 },
    dimText      = { 0.55, 0.58, 0.63 },
    tabNormal    = { 0.12, 0.14, 0.17, 0.65 },
    tabActive    = { 0.24, 0.21, 0.13, 0.95 },
    accentGreen  = { 0.20, 0.80, 0.30 },
    accentRed    = { 0.90, 0.25, 0.25 },
}

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

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

-- Registry of UI widgets for live refresh
local registeredWidgets = {}

--[[-----------------------------------------------------------------------------
    Smart Auto-Hiding Scrollbar
-------------------------------------------------------------------------------]]
local function SetupAutoScroll(scrollFrame, scrollChild)
    if not (scrollFrame and scrollChild) then return end
    local scrollBar = _G[scrollFrame:GetName() and (scrollFrame:GetName() .. "ScrollBar")]

    local function UpdateScrollState()
        local frameHeight = scrollFrame:GetHeight()
        local childHeight = scrollChild:GetHeight()
        if not frameHeight or frameHeight <= 0 then return end
        if childHeight <= frameHeight + 2 then
            if scrollBar and scrollBar:IsShown() then
                scrollBar:Hide()
            end
            scrollFrame:EnableMouseWheel(false)
            scrollFrame:SetVerticalScroll(0)
        else
            if scrollBar and not scrollBar:IsShown() then
                scrollBar:Show()
            end
            scrollFrame:EnableMouseWheel(true)
        end
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local frameHeight = self:GetHeight()
        local childHeight = scrollChild:GetHeight()
        if not frameHeight or childHeight <= frameHeight + 2 then return end
        local cur = self:GetVerticalScroll()
        local maxScroll = math.max(0, childHeight - frameHeight)
        local step = 32
        local newScroll = math.max(0, math.min(maxScroll, cur - (delta * step)))
        self:SetVerticalScroll(newScroll)
    end)

    scrollFrame:HookScript("OnSizeChanged", UpdateScrollState)
    scrollChild:HookScript("OnSizeChanged", UpdateScrollState)
    scrollFrame:HookScript("OnShow", UpdateScrollState)
    UpdateScrollState()
    return UpdateScrollState
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Section Header & Divider
-------------------------------------------------------------------------------]]
function UI:CreateSectionHeader(parent, text, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 16, y or 0)
    header:SetText(text)
    header:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    return header
end

function UI:CreateDivider(parent, y, width)
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    if width then
        div:SetWidth(width)
        div:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    else
        div:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
        div:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, y)
    end
    div:SetColorTexture(COLORS.goldMuted[1], COLORS.goldMuted[2], COLORS.goldMuted[3], 0.35)
    return div
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Checkbox
-------------------------------------------------------------------------------]]
function UI:CreateCheckbox(parent, name, labelText, x, y, getFunc, setFunc, tooltip)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.text = _G[name .. "Text"]
    if cb.text then
        cb.text:SetText(labelText)
        cb.text:SetFontObject("GameFontHighlight")
        cb.text:SetWordWrap(true)
        cb.text:SetJustifyH("LEFT")
    end

    cb.getFunc = getFunc
    cb.setFunc = setFunc
    cb:SetChecked(getFunc and getFunc() or false)

    cb:SetScript("OnClick", function(self)
        if self.setFunc then
            self.setFunc(self:GetChecked())
        end
    end)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(labelText, COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    table.insert(registeredWidgets, {
        type = "checkbox",
        frame = cb,
        update = function()
            if cb.getFunc then
                cb:SetChecked(cb.getFunc())
            end
        end,
    })

    return cb
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Slider
-------------------------------------------------------------------------------]]
function UI:CreateSlider(parent, name, labelText, minVal, maxVal, step, x, y, getFunc, setFunc, formatStr, tooltip)
    formatStr = formatStr or (step < 1 and "%.1f" or "%d")
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    if slider.SetObeyStepNumbers then
        slider:SetObeyStepNumbers(true)
    end
    slider:SetWidth(180)

    local low = _G[name .. "Low"]
    if low then low:SetText(tostring(minVal)) end
    local high = _G[name .. "High"]
    if high then high:SetText(tostring(maxVal)) end

    slider.getFunc = getFunc
    slider.setFunc = setFunc
    slider.formatStr = formatStr
    slider.labelText = labelText

    local curVal = getFunc and getFunc() or minVal
    local titleText = _G[name .. "Text"]
    if titleText then
        titleText:SetText(labelText .. ": " .. string.format(formatStr, curVal))
    end
    slider:SetValue(curVal)

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        local tt = _G[name .. "Text"]
        if tt then
            tt:SetText(self.labelText .. ": " .. string.format(self.formatStr, val))
        end
        if self.setFunc then
            self.setFunc(val)
        end
    end)

    if tooltip then
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(labelText, COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    table.insert(registeredWidgets, {
        type = "slider",
        frame = slider,
        update = function()
            if slider.getFunc then
                local v = slider.getFunc()
                slider:SetValue(v)
                local tt = _G[name .. "Text"]
                if tt then
                    tt:SetText(slider.labelText .. ": " .. string.format(slider.formatStr, v))
                end
            end
        end,
    })

    return slider
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Custom Dropdown (Dark Slate & Gold)
-------------------------------------------------------------------------------]]
local sharedDropdownMenu = nil
local sharedDropdownCatcher = nil

local function GetOrCreateLocalDropdownMenu()
    if sharedDropdownMenu then return sharedDropdownMenu end

    sharedDropdownCatcher = CreateFrame("Button", "BFC_DropdownCatcher", UIParent)
    sharedDropdownCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    sharedDropdownCatcher:SetFrameLevel(98)
    sharedDropdownCatcher:SetAllPoints(UIParent)
    sharedDropdownCatcher:EnableMouse(true)
    sharedDropdownCatcher:Hide()
    sharedDropdownCatcher:SetScript("OnClick", function()
        if sharedDropdownMenu then sharedDropdownMenu:Hide() end
    end)

    local menu = CreateFrame("Frame", "BFC_DropdownMenu", UIParent, BACKDROP_TEMPLATE)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(99)
    menu:SetClampedToScreen(true)
    menu:SetBackdrop(INSET_BACKDROP)
    menu:SetBackdropColor(0.08, 0.10, 0.13, 0.98)
    menu:SetBackdropBorderColor(unpack(COLORS.goldBorder))
    menu:EnableMouse(true)
    menu:Hide()

    menu:SetScript("OnShow", function() sharedDropdownCatcher:Show() end)
    menu:SetScript("OnHide", function() sharedDropdownCatcher:Hide() end)

    local scrollFrame = CreateFrame("ScrollFrame", "BFC_DropdownScrollFrame", menu, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -22, 4)
    menu.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(150, 100)
    scrollFrame:SetScrollChild(scrollChild)
    menu.scrollChild = scrollChild

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, scrollChild:GetHeight() - self:GetHeight())
        local newS = math.min(maxS, math.max(0, cur - (delta * 22)))
        self:SetVerticalScroll(newS)
    end)

    menu.buttons = {}
    sharedDropdownMenu = menu
    return menu
end

local function NormalizeDropdownItems(items)
    local list = {}
    if type(items) == "table" then
        if #items > 0 then
            for _, item in ipairs(items) do
                if type(item) == "table" then
                    local val = (item.value ~= nil) and item.value or ((item.key ~= nil) and item.key or item[1])
                    local text = item.text or item.label or item[2] or tostring(val)
                    table.insert(list, { value = val, text = text })
                else
                    table.insert(list, { value = item, text = tostring(item) })
                end
            end
        else
            for k, v in pairs(items) do
                table.insert(list, { value = k, text = tostring(v) })
            end
            table.sort(list, function(a, b) return a.text:lower() < b.text:lower() end)
        end
    end
    return list
end

function UI:GetAvailableFonts()
    local fonts = {}
    local seen = {}
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.List then
        local lsmList = LSM:List("font")
        if lsmList then
            for _, f in ipairs(lsmList) do
                if not seen[f] then
                    table.insert(fonts, { value = f, text = f })
                    seen[f] = true
                end
            end
        end
    end
    local standardFonts = {
        "Nata Sans Regular", "Nata Sans Bold", "Nata Sans Medium",
        "NullgateUI Regular", "NullgateUI Bold",
        "Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus"
    }
    for _, f in ipairs(standardFonts) do
        if not seen[f] then
            table.insert(fonts, { value = f, text = f })
            seen[f] = true
        end
    end
    table.sort(fonts, function(a, b) return a.text:lower() < b.text:lower() end)
    return fonts
end

function UI:CreateDropdown(parent, name, labelText, items, x, y, width, getFunc, setFunc, tooltip, isFont)
    width = width or 160
    local container = CreateFrame("Frame", name .. "Container", parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    container:SetSize(width, 42)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    container.label = label

    local btn = CreateFrame("Button", name, container, BACKDROP_TEMPLATE)
    btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    btn:SetSize(width, 22)
    btn:SetBackdrop(INSET_BACKDROP)
    btn:SetBackdropColor(unpack(COLORS.tabNormal))
    btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))
    container.button = btn

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btnText:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetWordWrap(false)
    btn.text = btnText

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetText("|cFFFFD100v|r")

    local function GetItemsList()
        if type(items) == "function" then
            return NormalizeDropdownItems(items())
        end
        return NormalizeDropdownItems(items)
    end

    local function GetItemText(val)
        local curItems = GetItemsList()
        for _, itm in ipairs(curItems) do
            if itm.value == val then
                return itm.text
            end
        end
        return tostring(val or "")
    end

    local function UpdateButtonText()
        local curVal = getFunc and getFunc()
        btnText:SetText(GetItemText(curVal))
        if isFont then
            local fontPath = BFC:FetchFont(curVal)
            if fontPath then
                pcall(function() btnText:SetFont(fontPath, 11, "") end)
            end
        end
    end
    UpdateButtonText()

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.22, 0.28, 0.95)
        self:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(labelText, COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.tabNormal))
        self:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        if tooltip then GameTooltip:Hide() end
    end)

    btn:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        local menu = GetOrCreateLocalDropdownMenu()
        if menu:IsShown() and menu.currentButton == self then
            menu:Hide()
            return
        end

        local curItems = GetItemsList()
        local curVal = getFunc and getFunc()
        menu.currentButton = self

        for _, b in ipairs(menu.buttons) do b:Hide() end

        local btnHeight = 22
        local maxVisible = 8
        local visibleCount = math.min(#curItems, maxVisible)
        local menuWidth = math.max(width, 160)
        local hasScroll = #curItems > maxVisible
        local totalContentHeight = #curItems * btnHeight

        menu.scrollChild:SetSize(menuWidth - (hasScroll and 26 or 8), totalContentHeight)

        local selectedIndex = 1
        for i, itm in ipairs(curItems) do
            local b = menu.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, menu.scrollChild, BACKDROP_TEMPLATE)
                b:SetHeight(btnHeight)
                b:SetBackdrop(INSET_BACKDROP)

                local bText = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                bText:SetPoint("LEFT", b, "LEFT", 8, 0)
                bText:SetPoint("RIGHT", b, "RIGHT", -8, 0)
                bText:SetJustifyH("LEFT")
                b.text = bText

                b:SetScript("OnEnter", function(btnSelf)
                    btnSelf:SetBackdropColor(0.28, 0.24, 0.15, 0.95)
                    btnSelf:SetBackdropBorderColor(unpack(COLORS.goldBorder))
                end)
                b:SetScript("OnLeave", function(btnSelf)
                    if btnSelf.isActive then
                        btnSelf:SetBackdropColor(0.22, 0.19, 0.12, 0.95)
                        btnSelf:SetBackdropBorderColor(unpack(COLORS.goldBorder))
                    else
                        btnSelf:SetBackdropColor(0.10, 0.12, 0.15, 0.50)
                        btnSelf:SetBackdropBorderColor(unpack(COLORS.goldMuted))
                    end
                end)

                menu.buttons[i] = b
            end

            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", menu.scrollChild, "TOPLEFT", 2, -((i - 1) * btnHeight))
            b:SetPoint("RIGHT", menu.scrollChild, "RIGHT", -2, 0)

            local isActive = (itm.value == curVal)
            b.isActive = isActive
            if isActive then
                selectedIndex = i
                b.text:SetText("|cFFFFD100* |r" .. itm.text)
                b:SetBackdropColor(0.22, 0.19, 0.12, 0.95)
                b:SetBackdropBorderColor(unpack(COLORS.goldBorder))
            else
                b.text:SetText("   " .. itm.text)
                b:SetBackdropColor(0.10, 0.12, 0.15, 0.50)
                b:SetBackdropBorderColor(unpack(COLORS.goldMuted))
            end

            if isFont then
                local fPath = BFC:FetchFont(itm.value)
                if fPath then
                    pcall(function() b.text:SetFont(fPath, 11, "") end)
                end
            else
                b.text:SetFontObject("GameFontHighlightSmall")
            end

            local chosenValue = itm.value
            b:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                if setFunc then
                    setFunc(chosenValue)
                end
                UpdateButtonText()
                menu:Hide()
            end)
            b:Show()
        end

        local menuHeight = (visibleCount * btnHeight) + 8
        menu:SetSize(menuWidth, menuHeight)

        local screenHeight = UIParent:GetHeight() or 768
        local btnBottom = self:GetBottom() or (screenHeight / 2)
        menu:ClearAllPoints()
        if btnBottom < (menuHeight + 20) then
            menu:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
        else
            menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        end

        menu:Show()
        menu:Raise()

        if hasScroll then
            local scrollPos = math.max(0, math.min(totalContentHeight - (visibleCount * btnHeight), (selectedIndex - 1) * btnHeight))
            menu.scrollFrame:SetVerticalScroll(scrollPos)
        else
            menu.scrollFrame:SetVerticalScroll(0)
        end
    end)

    container.Sync = UpdateButtonText

    table.insert(registeredWidgets, {
        type = "dropdown",
        frame = container,
        update = UpdateButtonText,
    })

    return container
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Button
-------------------------------------------------------------------------------]]
function UI:CreateButton(parent, name, text, x, y, width, height, onClick)
    width = width or 120
    height = height or 22
    local btn = CreateFrame("Button", name, parent, BACKDROP_TEMPLATE)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetSize(width, height)
    btn:SetBackdrop(INSET_BACKDROP)
    btn:SetBackdropColor(unpack(COLORS.tabNormal))
    btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text)
    label:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.22, 0.28, 0.95)
        self:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.tabNormal))
        self:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        label:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end

--[[-----------------------------------------------------------------------------
    Widget Factory: EditBox
-------------------------------------------------------------------------------]]
function UI:CreateEditBox(parent, name, labelText, x, y, width, getFunc, setFunc)
    width = width or 200
    local container = CreateFrame("Frame", name .. "Container", parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    container:SetSize(width, 44)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    container.label = label

    local eb = CreateFrame("EditBox", name, container, BACKDROP_TEMPLATE)
    eb:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    eb:SetSize(width, 22)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetBackdrop(INSET_BACKDROP)
    eb:SetBackdropColor(unpack(COLORS.contentBg))
    eb:SetBackdropBorderColor(unpack(COLORS.goldMuted))
    eb:SetTextInsets(6, 6, 0, 0)
    container.editBox = eb

    local cur = getFunc and getFunc() or ""
    eb:SetText(cur)

    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if setFunc then setFunc(self:GetText()) end
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        if setFunc then setFunc(self:GetText()) end
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText(getFunc and getFunc() or "")
    end)

    container.SetText = function(self, val)
        eb:SetText(val or "")
    end
    container.GetText = function(self)
        return eb:GetText()
    end

    table.insert(registeredWidgets, {
        type = "editbox",
        frame = container,
        update = function()
            local v = getFunc and getFunc() or ""
            eb:SetText(v)
        end,
    })

    return container
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Color Picker
-------------------------------------------------------------------------------]]
function UI:CreateColorPicker(parent, name, labelText, x, y, getFunc, setFunc)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetSize(180, 26)

    local swatch = CreateFrame("Button", name .. "Swatch", frame, BACKDROP_TEMPLATE)
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT", frame, "LEFT", 0, 0)
    swatch:SetBackdrop(INSET_BACKDROP)
    swatch:SetBackdropBorderColor(unpack(COLORS.goldBorder))

    local colorTex = swatch:CreateTexture(nil, "ARTWORK")
    colorTex:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
    colorTex:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)

    local cur = getFunc and getFunc() or { r = 1, g = 1, b = 1 }
    colorTex:SetColorTexture(cur.r or 1, cur.g or 1, cur.b or 1, 1)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    label:SetText(labelText)

    swatch:SetScript("OnClick", function()
        local c = getFunc and getFunc() or { r = 1, g = 1, b = 1 }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            colorTex:SetColorTexture(r, g, b, 1)
            if setFunc then setFunc({ r = r, g = g, b = b }) end
        end
        ColorPickerFrame.cancelFunc = function(prev)
            colorTex:SetColorTexture(c.r, c.g, c.b, 1)
            if setFunc then setFunc(c) end
        end
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:Show()
    end)

    table.insert(registeredWidgets, {
        type = "colorpicker",
        frame = frame,
        update = function()
            local c = getFunc and getFunc() or { r = 1, g = 1, b = 1 }
            colorTex:SetColorTexture(c.r or 1, c.g or 1, c.b or 1, 1)
        end,
    })

    return frame
end

--[[-----------------------------------------------------------------------------
    Options Panel Layout (Tabbed & Responsive Reflow)
-------------------------------------------------------------------------------]]
function UI:BuildOptions(parentContainer, isMasterHub)
    isMasterHub = isMasterHub or (parentContainer and parentContainer.isMasterHub) or false

    local db = BFC.db or (BFC.InitDB and BFC:InitDB()) or {}
    registeredWidgets = {}

    -- Subtitle / description
    local subtext = parentContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtext:SetText("Configure chat history, URL links, whisper popouts, player class colors, and typography.")
    subtext:SetTextColor(COLORS.dimText[1], COLORS.dimText[2], COLORS.dimText[3])

    if not isMasterHub then
        local header = parentContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", parentContainer, "TOPLEFT", 16, -14)
        header:SetText(FULL_TITLE)
        header:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
        subtext:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    else
        subtext:SetPoint("TOPLEFT", parentContainer, "TOPLEFT", 16, -12)
    end

    -- Sub-Tab Navigation Bar
    local tabsContainer = CreateFrame("Frame", nil, parentContainer)
    tabsContainer:SetHeight(28)
    tabsContainer:SetPoint("TOPLEFT", subtext, "BOTTOMLEFT", 0, -8)
    tabsContainer:SetPoint("RIGHT", parentContainer, "RIGHT", -16, 0)

    -- Inset Content Pane for Active Tab
    local tabContent = CreateFrame("Frame", nil, parentContainer, BACKDROP_TEMPLATE)
    tabContent:SetPoint("TOPLEFT", tabsContainer, "BOTTOMLEFT", 0, -6)
    tabContent:SetPoint("BOTTOMRIGHT", parentContainer, "BOTTOMRIGHT", -16, 12)
    tabContent:SetBackdrop(INSET_BACKDROP)
    tabContent:SetBackdropColor(unpack(COLORS.contentBg))
    tabContent:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    -- ScrollFrame for Tab Content
    local scrollFrame = CreateFrame("ScrollFrame", "NullgateChatOptionsScrollFrame", tabContent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tabContent, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", tabContent, "BOTTOMRIGHT", -26, 8)

    local pWidth = parentContainer:GetWidth()
    local contentWidth = (pWidth and pWidth > 150) and (pWidth - 48) or 540
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(contentWidth, 600)
    scrollFrame:SetScrollChild(scrollChild)

    local updateScroll = SetupAutoScroll(scrollFrame, scrollChild)

    -- Tab definitions
    local tabs = {
        { id = "general",  title = "General" },
        { id = "history",  title = "History" },
        { id = "layout",   title = "Layout & Style" },
        { id = "profiles", title = "Profiles" },
    }

    local tabButtons = {}
    local tabPanes = {}
    local activeTab = "general"

    --[[-------------------------------------------------------------------------
        Tab 1: General (URL Links, Whispers, Class Colors, Formatting)
    ---------------------------------------------------------------------------]]
    local pGeneral = CreateFrame("Frame", nil, scrollChild)
    pGeneral:SetAllPoints(scrollChild)
    tabPanes["general"] = pGeneral

    local hLinks = self:CreateSectionHeader(pGeneral, "Link Clicking & URLs", 16, 0)
    local cbUrlLinks = self:CreateCheckbox(pGeneral, "BFC_CbUrlLinks", "Enable Clickable URL Links", 16, 0,
        function() return db.enableUrlLinks ~= false end,
        function(v)
            db.enableUrlLinks = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Automatically identifies web URLs in chat and turns them into clickable links that open a copy dialog."
    )
    local cpUrlColor = self:CreateColorPicker(pGeneral, "BFC_CpUrlColor", "URL Accent Color", 16, 0,
        function() return db.urlColor or { r = 0.20, g = 0.85, b = 1.00 } end,
        function(v)
            db.urlColor = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end
    )

    local hWhispers = self:CreateSectionHeader(pGeneral, "Whispers & Tabs", 16, 0)
    local cbWhisperWindow = self:CreateCheckbox(pGeneral, "BFC_CbWhisperWindow", "Whispers to New Window / Tab (Default)", 16, 0,
        function() return db.whisperWindow ~= false end,
        function(v)
            db.whisperWindow = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Routes incoming and outgoing tells to their own dedicated tab by default."
    )
    local cbWhisperGlow = self:CreateCheckbox(pGeneral, "BFC_CbWhisperGlow", "Flash Whisper Tabs on New Message", 16, 0,
        function() return db.whisperNotifyGlow ~= false end,
        function(v) db.whisperNotifyGlow = v end,
        "Glows and pulses the whisper tab when a new whisper arrives."
    )

    local hFormatting = self:CreateSectionHeader(pGeneral, "Names & Channel Formatting", 16, 0)
    local cbClassColors = self:CreateCheckbox(pGeneral, "BFC_CbClassColors", "Universal Class Color Character Names", 16, 0,
        function() return db.classColorNames ~= false end,
        function(v)
            db.classColorNames = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Formats character names in their class color across whispers, guild, party, raid, say, yell, and channels."
    )
    local cbShortChannels = self:CreateCheckbox(pGeneral, "BFC_CbShortChannels", "Shorten Channel Names ([1], [G], [P], [R])", 16, 0,
        function() return db.shortChannelNames ~= false end,
        function(v) db.shortChannelNames = v end,
        "Replaces long channel tags with compact bracketed abbreviations."
    )
    local cbTimestamps = self:CreateCheckbox(pGeneral, "BFC_CbTimestamps", "Show Timestamps", 16, 0,
        function() return db.showTimestamps ~= false end,
        function(v) db.showTimestamps = v end,
        "Prepends chat messages with a timestamp."
    )
    local ddTimestampFormat = self:CreateDropdown(pGeneral, "BFC_DdTimestampFormat", "Timestamp Format", {
        { value = "%H:%M", text = "24-Hour (14:30)" },
        { value = "%H:%M:%S", text = "24-Hour w/ Seconds (14:30:15)" },
        { value = "%I:%M %p", text = "12-Hour (02:30 PM)" },
    }, 16, 0, 180,
        function() return db.timestampFormat or "%H:%M" end,
        function(v) db.timestampFormat = v end,
        "Select the display format for chat timestamps."
    )

    local function LayoutGeneral(w)
        local isWide = (w >= 470)
        local colWidth = isWide and math.floor((w - 48) / 2) or (w - 32)
        local col1X = 16
        local col2X = isWide and (col1X + colWidth + 16) or 16

        local y = -12
        hLinks:ClearAllPoints()
        hLinks:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
        y = y - 26

        if isWide then
            cbUrlLinks:ClearAllPoints()
            cbUrlLinks:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            cpUrlColor:ClearAllPoints()
            cpUrlColor:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col2X, y + 2)
            if cbUrlLinks.text then cbUrlLinks.text:SetWidth(colWidth - 32) end
            y = y - 44
        else
            cbUrlLinks:ClearAllPoints()
            cbUrlLinks:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            if cbUrlLinks.text then cbUrlLinks.text:SetWidth(colWidth - 32) end
            y = y - 36
            cpUrlColor:ClearAllPoints()
            cpUrlColor:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X + 4, y)
            y = y - 36
        end

        hWhispers:ClearAllPoints()
        hWhispers:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
        y = y - 26

        if isWide then
            cbWhisperWindow:ClearAllPoints()
            cbWhisperWindow:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            cbWhisperGlow:ClearAllPoints()
            cbWhisperGlow:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col2X, y)
            if cbWhisperWindow.text then cbWhisperWindow.text:SetWidth(colWidth - 32) end
            if cbWhisperGlow.text then cbWhisperGlow.text:SetWidth(colWidth - 32) end
            y = y - 44
        else
            cbWhisperWindow:ClearAllPoints()
            cbWhisperWindow:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            if cbWhisperWindow.text then cbWhisperWindow.text:SetWidth(colWidth - 32) end
            y = y - 36
            cbWhisperGlow:ClearAllPoints()
            cbWhisperGlow:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            if cbWhisperGlow.text then cbWhisperGlow.text:SetWidth(colWidth - 32) end
            y = y - 36
        end

        hFormatting:ClearAllPoints()
        hFormatting:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
        y = y - 26

        if isWide then
            cbClassColors:ClearAllPoints()
            cbClassColors:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            cbShortChannels:ClearAllPoints()
            cbShortChannels:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col2X, y)
            if cbClassColors.text then cbClassColors.text:SetWidth(colWidth - 32) end
            if cbShortChannels.text then cbShortChannels.text:SetWidth(colWidth - 32) end
            y = y - 40

            cbTimestamps:ClearAllPoints()
            cbTimestamps:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            ddTimestampFormat:ClearAllPoints()
            ddTimestampFormat:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col2X, y + 6)
            if cbTimestamps.text then cbTimestamps.text:SetWidth(colWidth - 32) end
            y = y - 56
        else
            cbClassColors:ClearAllPoints()
            cbClassColors:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            if cbClassColors.text then cbClassColors.text:SetWidth(colWidth - 32) end
            y = y - 36

            cbShortChannels:ClearAllPoints()
            cbShortChannels:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            if cbShortChannels.text then cbShortChannels.text:SetWidth(colWidth - 32) end
            y = y - 36

            cbTimestamps:ClearAllPoints()
            cbTimestamps:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            if cbTimestamps.text then cbTimestamps.text:SetWidth(colWidth - 32) end
            y = y - 36

            ddTimestampFormat:ClearAllPoints()
            ddTimestampFormat:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", col1X, y)
            y = y - 52
        end

        pGeneral.contentHeight = math.abs(y) + 30
    end

    --[[-------------------------------------------------------------------------
        Tab 2: History (Chat Buffers, Session Divider, Sticky Channels)
    ---------------------------------------------------------------------------]]
    local pHistory = CreateFrame("Frame", nil, scrollChild)
    pHistory:SetAllPoints(scrollChild)
    tabPanes["history"] = pHistory

    local hChatHistory = self:CreateSectionHeader(pHistory, "Chat Message History Buffer", 16, 0)
    local cbEnableHistory = self:CreateCheckbox(pHistory, "BFC_CbEnableHistory", "Enable Chat History across /reload and Relog", 16, 0,
        function() return db.enableChatHistory ~= false end,
        function(v) db.enableChatHistory = v end,
        "Saves recent chat lines per tab in SavedVariables and restores them upon entering world."
    )
    local slHistoryLines = self:CreateSlider(pHistory, "BFC_SlHistoryLines", "Buffer Size", 50, 500, 25, 16, 0,
        function() return db.chatHistoryLines or 200 end,
        function(v) db.chatHistoryLines = v end,
        "%d lines",
        "Maximum number of lines kept in memory per chat tab."
    )
    local cbSessionDivider = self:CreateCheckbox(pHistory, "BFC_CbSessionDivider", "Show Session Divider on Login", 16, 0,
        function() return db.showSessionDivider ~= false end,
        function(v) db.showSessionDivider = v end,
        "Prints a subtle divider separating past session messages from fresh chat."
    )
    local btnClearHistory = self:CreateButton(pHistory, "BFC_BtnClearHistory", "Clear Stored History", 16, 0, 160, 24, function()
        if BFC.ClearHistory then
            BFC:ClearHistory()
        elseif _G["NullgatesChatHistory"] then
            wipe(_G["NullgatesChatHistory"])
        end
        print("|cff00c0ffNullgate's Chat:|r History buffer cleared.")
    end)

    local hSticky = self:CreateSectionHeader(pHistory, "EditBox & Command Memory", 16, 0)
    local cbSticky = self:CreateCheckbox(pHistory, "BFC_CbSticky", "Remember Sticky Channels (/p, /g, /ra, /w)", 16, 0,
        function() return db.stickyChannels ~= false end,
        function(v)
            db.stickyChannels = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Remembers the last channel used so you do not have to retype the prefix when chatting."
    )
    local cbEditBoxHistory = self:CreateCheckbox(pHistory, "BFC_CbEditBoxHistory", "Remember Sent Commands (Up/Down Arrow History)", 16, 0,
        function() return db.enableEditBoxHistory ~= false end,
        function(v) db.enableEditBoxHistory = v end,
        "Saves recently sent chat messages and slash commands across reload and relogs, recallable with the Up/Down arrow keys."
    )
    local slEditBoxLines = self:CreateSlider(pHistory, "BFC_SlEditBoxLines", "Command Buffer Size", 10, 100, 5, 16, 0,
        function() return db.editBoxHistoryLines or 50 end,
        function(v) db.editBoxHistoryLines = v end,
        "%d lines",
        "Maximum number of recent commands and messages saved in memory."
    )

    local function LayoutHistory(w)
        local isWide = (w >= 470)
        local colWidth = isWide and math.floor((w - 48) / 2) or (w - 32)
        local col1X = 16
        local col2X = isWide and (col1X + colWidth + 16) or 16

        local y = -12
        hChatHistory:ClearAllPoints()
        hChatHistory:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
        y = y - 26

        cbEnableHistory:ClearAllPoints()
        cbEnableHistory:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
        if cbEnableHistory.text then cbEnableHistory.text:SetWidth(w - 48) end
        y = y - 36

        if isWide then
            slHistoryLines:ClearAllPoints()
            slHistoryLines:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
            cbSessionDivider:ClearAllPoints()
            cbSessionDivider:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col2X, y)
            if cbSessionDivider.text then cbSessionDivider.text:SetWidth(colWidth - 32) end
            y = y - 48
        else
            slHistoryLines:ClearAllPoints()
            slHistoryLines:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
            y = y - 46
            cbSessionDivider:ClearAllPoints()
            cbSessionDivider:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
            if cbSessionDivider.text then cbSessionDivider.text:SetWidth(colWidth - 32) end
            y = y - 36
        end

        btnClearHistory:ClearAllPoints()
        btnClearHistory:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
        y = y - 44

        hSticky:ClearAllPoints()
        hSticky:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
        y = y - 26

        cbSticky:ClearAllPoints()
        cbSticky:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
        if cbSticky.text then cbSticky.text:SetWidth(w - 48) end
        y = y - 36

        if isWide then
            cbEditBoxHistory:ClearAllPoints()
            cbEditBoxHistory:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
            slEditBoxLines:ClearAllPoints()
            slEditBoxLines:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col2X, y)
            if cbEditBoxHistory.text then cbEditBoxHistory.text:SetWidth(colWidth - 32) end
            y = y - 52
        else
            cbEditBoxHistory:ClearAllPoints()
            cbEditBoxHistory:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
            if cbEditBoxHistory.text then cbEditBoxHistory.text:SetWidth(colWidth - 32) end
            y = y - 36
            slEditBoxLines:ClearAllPoints()
            slEditBoxLines:SetPoint("TOPLEFT", pHistory, "TOPLEFT", col1X, y)
            y = y - 48
        end

        pHistory.contentHeight = math.abs(y) + 30
    end

    --[[-------------------------------------------------------------------------
        Tab 3: Layout & Style (Typography, Docking, Clutter Suppression)
    ---------------------------------------------------------------------------]]
    local pLayout = CreateFrame("Frame", nil, scrollChild)
    pLayout:SetAllPoints(scrollChild)
    tabPanes["layout"] = pLayout

    local hTypography = self:CreateSectionHeader(pLayout, "Typography & Fonts", 16, 0)
    local ddFont = self:CreateDropdown(pLayout, "BFC_DdFont", "Chat Font", function() return UI:GetAvailableFonts() end, 16, 0, 180,
        function() return db.font or "Nata Sans Regular" end,
        function(v)
            db.font = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Select the primary font face used for chat tabs and messages.",
        true
    )
    local slFontSize = self:CreateSlider(pLayout, "BFC_SlFontSize", "Font Size", 9, 24, 1, 16, 0,
        function() return db.fontSize or 12 end,
        function(v)
            db.fontSize = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "%d pt",
        "Base text font size for chat messages."
    )
    local ddOutline = self:CreateDropdown(pLayout, "BFC_DdOutline", "Font Outline", {
        { value = "NONE", text = "None" },
        { value = "OUTLINE", text = "Thin Outline" },
        { value = "THICKOUTLINE", text = "Thick Outline" },
    }, 16, 0, 180,
        function() return db.fontOutline or "OUTLINE" end,
        function(v)
            db.fontOutline = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Select font rendering outline."
    )

    local hBackdrop = self:CreateSectionHeader(pLayout, "Chat Frame Backdrops & Styling", 16, 0)
    local cbCustomBackdrop = self:CreateCheckbox(pLayout, "BFC_CbCustomBackdrop", "Enable Dark Slate & Gold Frame Backdrop", 16, 0,
        function() return db.enableCustomBackdrop == true end,
        function(v)
            db.enableCustomBackdrop = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Displays a clean Dark Slate background and subtle gold border behind chat windows."
    )
    local slBackdropAlpha = self:CreateSlider(pLayout, "BFC_SlBackdropAlpha", "Backdrop Opacity", 0.1, 1.0, 0.05, 16, 0,
        function() return db.backdropAlpha or 0.65 end,
        function(v)
            db.backdropAlpha = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "%.2f",
        "Controls the background opacity of the custom chat frame backdrop."
    )
    local cbEditBoxBackdrop = self:CreateCheckbox(pLayout, "BFC_CbEditBoxBackdrop", "Dark Slate & Gold EditBox Skinning", 16, 0,
        function() return db.editBoxBackdrop ~= false end,
        function(v)
            db.editBoxBackdrop = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Applies Dark Slate & Gold backdrop skinning and focus glow effects to the chat entry box."
    )

    local hClutter = self:CreateSectionHeader(pLayout, "Ergonomics & Clutter Suppression", 16, 0)
    local ddEditBoxPos = self:CreateDropdown(pLayout, "BFC_DdEditBoxPos", "EditBox Position", {
        { value = "BOTTOM", text = "Docked Below (Bottom)" },
        { value = "TOP", text = "Docked Above (Top)" },
    }, 16, 0, 180,
        function() return db.editBoxPosition or "BOTTOM" end,
        function(v)
            db.editBoxPosition = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Anchor position of the chat text entry box."
    )
    local cbCopyButton = self:CreateCheckbox(pLayout, "BFC_CbCopyButton", "Show Copy Button on Chat Tabs", 16, 0,
        function() return db.showCopyButton ~= false end,
        function(v)
            db.showCopyButton = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Displays a subtle copy button on chat frames to open the plain-text message extraction dialog."
    )
    local cbMouseWheel = self:CreateCheckbox(pLayout, "BFC_CbMouseWheel", "Mousewheel Scrolling (Shift+Wheel to Jump)", 16, 0,
        function() return db.enableMouseWheel ~= false end,
        function(v)
            db.enableMouseWheel = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Scrolls chat up and down with the mouse wheel. Hold Shift to jump directly to the top or bottom."
    )
    local cbHideButtons = self:CreateCheckbox(pLayout, "BFC_CbHideButtons", "Hide Blizzard Menu, Voice & Channel Buttons", 16, 0,
        function() return db.hideChatButtons ~= false end,
        function(v)
            db.hideChatButtons = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Suppresses intrusive Blizzard menu and voice buttons for a minimal aesthetic."
    )
    local cbHideScrollButtons = self:CreateCheckbox(pLayout, "BFC_CbHideScrollButtons", "Hide Bottom Scroll Arrow Buttons", 16, 0,
        function() return db.hideScrollButtons ~= false end,
        function(v)
            db.hideScrollButtons = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Hides the default bottom-scroll and arrow buttons."
    )
    local cbUnclamp = self:CreateCheckbox(pLayout, "BFC_CbUnclamp", "Unclamp Frames (Allow Flush Screen Placement)", 16, 0,
        function() return db.unclampFromScreen ~= false end,
        function(v)
            db.unclampFromScreen = v
            if BFC.ApplySettings then BFC:ApplySettings() end
        end,
        "Allows positioning chat windows completely flush against the edge of the screen."
    )

    local function LayoutLayoutTab(w)
        local isWide = (w >= 470)
        local colWidth = isWide and math.floor((w - 48) / 2) or (w - 32)
        local col1X = 16
        local col2X = isWide and (col1X + colWidth + 16) or 16

        local y = -12
        hTypography:ClearAllPoints()
        hTypography:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
        y = y - 26

        if isWide then
            ddFont:ClearAllPoints()
            ddFont:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            slFontSize:ClearAllPoints()
            slFontSize:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col2X, y)
            y = y - 52

            ddOutline:ClearAllPoints()
            ddOutline:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            y = y - 52
        else
            ddFont:ClearAllPoints()
            ddFont:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            y = y - 50
            slFontSize:ClearAllPoints()
            slFontSize:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            y = y - 48
            ddOutline:ClearAllPoints()
            ddOutline:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            y = y - 52
        end

        hBackdrop:ClearAllPoints()
        hBackdrop:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
        y = y - 26

        if isWide then
            cbCustomBackdrop:ClearAllPoints()
            cbCustomBackdrop:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            slBackdropAlpha:ClearAllPoints()
            slBackdropAlpha:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col2X, y)
            if cbCustomBackdrop.text then cbCustomBackdrop.text:SetWidth(colWidth - 32) end
            y = y - 48

            cbEditBoxBackdrop:ClearAllPoints()
            cbEditBoxBackdrop:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            if cbEditBoxBackdrop.text then cbEditBoxBackdrop.text:SetWidth(w - 48) end
            y = y - 36
        else
            cbCustomBackdrop:ClearAllPoints()
            cbCustomBackdrop:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            if cbCustomBackdrop.text then cbCustomBackdrop.text:SetWidth(colWidth - 32) end
            y = y - 36

            slBackdropAlpha:ClearAllPoints()
            slBackdropAlpha:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            y = y - 48

            cbEditBoxBackdrop:ClearAllPoints()
            cbEditBoxBackdrop:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            if cbEditBoxBackdrop.text then cbEditBoxBackdrop.text:SetWidth(colWidth - 32) end
            y = y - 36
        end

        hClutter:ClearAllPoints()
        hClutter:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
        y = y - 26

        if isWide then
            ddEditBoxPos:ClearAllPoints()
            ddEditBoxPos:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            cbCopyButton:ClearAllPoints()
            cbCopyButton:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col2X, y + 16)
            if cbCopyButton.text then cbCopyButton.text:SetWidth(colWidth - 32) end
            y = y - 50

            cbMouseWheel:ClearAllPoints()
            cbMouseWheel:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            cbUnclamp:ClearAllPoints()
            cbUnclamp:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col2X, y)
            if cbMouseWheel.text then cbMouseWheel.text:SetWidth(colWidth - 32) end
            if cbUnclamp.text then cbUnclamp.text:SetWidth(colWidth - 32) end
            y = y - 40

            cbHideButtons:ClearAllPoints()
            cbHideButtons:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            cbHideScrollButtons:ClearAllPoints()
            cbHideScrollButtons:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col2X, y)
            if cbHideButtons.text then cbHideButtons.text:SetWidth(colWidth - 32) end
            if cbHideScrollButtons.text then cbHideScrollButtons.text:SetWidth(colWidth - 32) end
            y = y - 44
        else
            ddEditBoxPos:ClearAllPoints()
            ddEditBoxPos:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            y = y - 50

            cbCopyButton:ClearAllPoints()
            cbCopyButton:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            if cbCopyButton.text then cbCopyButton.text:SetWidth(colWidth - 32) end
            y = y - 36

            cbMouseWheel:ClearAllPoints()
            cbMouseWheel:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            if cbMouseWheel.text then cbMouseWheel.text:SetWidth(colWidth - 32) end
            y = y - 36

            cbUnclamp:ClearAllPoints()
            cbUnclamp:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            if cbUnclamp.text then cbUnclamp.text:SetWidth(colWidth - 32) end
            y = y - 36

            cbHideButtons:ClearAllPoints()
            cbHideButtons:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            if cbHideButtons.text then cbHideButtons.text:SetWidth(colWidth - 32) end
            y = y - 36

            cbHideScrollButtons:ClearAllPoints()
            cbHideScrollButtons:SetPoint("TOPLEFT", pLayout, "TOPLEFT", col1X, y)
            if cbHideScrollButtons.text then cbHideScrollButtons.text:SetWidth(colWidth - 32) end
            y = y - 36
        end

        pLayout.contentHeight = math.abs(y) + 30
    end

    --[[-------------------------------------------------------------------------
        Tab 4: Profiles (Non-Destructive Profile Cloner & Manager)
    ---------------------------------------------------------------------------]]
    local pProfiles = CreateFrame("Frame", nil, scrollChild)
    pProfiles:SetAllPoints(scrollChild)
    tabPanes["profiles"] = pProfiles

    local hProfiles = self:CreateSectionHeader(pProfiles, "Profile Management", 16, 0)
    local subProfiles = pProfiles:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subProfiles:SetText("Create and switch configurations. Creating a new profile automatically clones your current settings.")
    subProfiles:SetTextColor(COLORS.dimText[1], COLORS.dimText[2], COLORS.dimText[3])

    local ddProfiles = self:CreateDropdown(pProfiles, "BFC_DdProfiles", "Active Profile",
        function() return BFC:GetProfileList() end,
        16, 0, 180,
        function() return BFC:GetActiveProfile() end,
        function(v)
            BFC:SetProfile(v)
            UI:Refresh()
        end,
        "Select the active configuration profile."
    )

    local newProfileName = ""
    local ebNewProfile = self:CreateEditBox(pProfiles, "BFC_EbNewProfile", "New Profile Name", 16, 0, 180,
        function() return newProfileName end,
        function(v) newProfileName = v or "" end
    )

    local btnCreateProfile = self:CreateButton(pProfiles, "BFC_BtnCreateProfile", "Create Profile", 16, 0, 110, 22, function()
        if newProfileName and newProfileName:trim() ~= "" then
            BFC:CreateProfile(newProfileName:trim())
            newProfileName = ""
            if ebNewProfile and ebNewProfile.SetText then ebNewProfile:SetText("") end
            UI:Refresh()
            print(string.format("|cff00c0ffNullgate's Chat:|r Profile created."))
        end
    end)

    local copyProfileKey = ""
    local ddCopyProfile = self:CreateDropdown(pProfiles, "BFC_DdCopyProfile", "Copy From",
        function() return BFC:GetProfileList() end,
        16, 0, 180,
        function() return copyProfileKey end,
        function(v) copyProfileKey = v end,
        "Select a profile to copy settings from into the currently active profile."
    )

    local btnCopyProfile = self:CreateButton(pProfiles, "BFC_BtnCopyProfile", "Copy Settings", 16, 0, 110, 22, function()
        if copyProfileKey and copyProfileKey ~= "" then
            BFC:CopyProfile(copyProfileKey)
            UI:Refresh()
            print(string.format("|cff00c0ffNullgate's Chat:|r Profile copied from |cffffd100%s|r.", copyProfileKey))
        end
    end)

    local btnResetProfile = self:CreateButton(pProfiles, "BFC_BtnResetProfile", "Reset Profile to Default", 16, 0, 160, 22, function()
        BFC:ResetProfile()
        UI:Refresh()
        print("|cff00c0ffNullgate's Chat:|r Active profile reset to defaults.")
    end)

    local btnDeleteProfile = self:CreateButton(pProfiles, "BFC_BtnDeleteProfile", "Delete Active Profile", 16, 0, 140, 22, function()
        local cur = BFC:GetActiveProfile()
        if cur and cur ~= "Default" then
            BFC:DeleteProfile(cur)
            UI:Refresh()
            print(string.format("|cff00c0ffNullgate's Chat:|r Profile |cffffd100%s|r deleted.", cur))
        else
            print("|cff00c0ffNullgate's Chat:|r Cannot delete the Default profile.")
        end
    end)

    local function LayoutProfiles(w)
        local isWide = (w >= 470)
        local colWidth = isWide and math.floor((w - 48) / 2) or (w - 32)
        local col1X = 16
        local col2X = isWide and (col1X + colWidth + 16) or 16

        local y = -12
        hProfiles:ClearAllPoints()
        hProfiles:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
        y = y - 22

        subProfiles:ClearAllPoints()
        subProfiles:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
        subProfiles:SetWidth(w - 32)
        y = y - 36

        ddProfiles:ClearAllPoints()
        ddProfiles:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
        y = y - 56

        if isWide then
            ebNewProfile:ClearAllPoints()
            ebNewProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
            btnCreateProfile:ClearAllPoints()
            btnCreateProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col2X, y - 18)
            y = y - 56

            ddCopyProfile:ClearAllPoints()
            ddCopyProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
            btnCopyProfile:ClearAllPoints()
            btnCopyProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col2X, y - 18)
            y = y - 56
        else
            ebNewProfile:ClearAllPoints()
            ebNewProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
            y = y - 50
            btnCreateProfile:ClearAllPoints()
            btnCreateProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
            y = y - 36

            ddCopyProfile:ClearAllPoints()
            ddCopyProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
            y = y - 50
            btnCopyProfile:ClearAllPoints()
            btnCopyProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
            y = y - 36
        end

        btnResetProfile:ClearAllPoints()
        btnResetProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
        y = y - 34

        btnDeleteProfile:ClearAllPoints()
        btnDeleteProfile:SetPoint("TOPLEFT", pProfiles, "TOPLEFT", col1X, y)
        y = y - 36

        pProfiles.contentHeight = math.abs(y) + 30
    end

    local function LayoutTabButtons()
        local barWidth = tabsContainer:GetWidth()
        if not barWidth or barWidth < 100 then return end
        local numTabs = #tabs
        local spacing = 4
        local totalSpacing = (numTabs - 1) * spacing
        local tabW = math.floor((barWidth - totalSpacing) / numTabs)

        for i, t in ipairs(tabs) do
            local btn = tabButtons[t.id]
            if not btn then
                btn = CreateFrame("Button", nil, tabsContainer, BACKDROP_TEMPLATE)
                btn:SetHeight(24)
                btn:SetBackdrop(INSET_BACKDROP)
                local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                lbl:SetPoint("CENTER", btn, "CENTER", 0, 0)
                lbl:SetText(t.title)
                btn.label = lbl

                local tabKey = t.id
                btn:SetScript("OnClick", function()
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                    ShowTab(tabKey)
                end)

                btn:SetScript("OnEnter", function(self)
                    if activeTab ~= tabKey then
                        self:SetBackdropColor(0.18, 0.20, 0.24, 0.85)
                    end
                end)
                btn:SetScript("OnLeave", function(self)
                    if activeTab ~= tabKey then
                        self:SetBackdropColor(unpack(COLORS.tabNormal))
                    end
                end)

                tabButtons[t.id] = btn
            end

            btn:ClearAllPoints()
            btn:SetWidth(tabW)
            btn:SetPoint("LEFT", tabsContainer, "LEFT", (i - 1) * (tabW + spacing), 0)
        end
    end

    local function LayoutAllTabs(w)
        w = w or scrollFrame:GetWidth() or contentWidth or 540
        if not w or w < 100 then w = 540 end
        scrollChild:SetWidth(w)
        LayoutGeneral(w)
        LayoutHistory(w)
        LayoutLayoutTab(w)
        LayoutProfiles(w)
        local curPane = tabPanes[activeTab]
        if curPane and curPane.contentHeight then
            scrollChild:SetHeight(curPane.contentHeight)
        end
        LayoutTabButtons()
        if updateScroll then updateScroll() end
    end

    -- Tab Switcher
    function ShowTab(tabId)
        activeTab = tabId
        for _, t in ipairs(tabs) do
            local pane = tabPanes[t.id]
            local btn = tabButtons[t.id]
            if t.id == tabId then
                if pane then pane:Show() end
                if btn then
                    btn:SetBackdropColor(unpack(COLORS.tabActive))
                    btn:SetBackdropBorderColor(unpack(COLORS.goldBorder))
                    if btn.label then btn.label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3]) end
                end
            else
                if pane then pane:Hide() end
                if btn then
                    btn:SetBackdropColor(unpack(COLORS.tabNormal))
                    btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))
                    if btn.label then btn.label:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3]) end
                end
            end
        end

        local w = scrollFrame:GetWidth() or scrollChild:GetWidth() or contentWidth or 540
        if not w or w < 100 then w = 540 end
        if tabId == "general" then LayoutGeneral(w)
        elseif tabId == "history" then LayoutHistory(w)
        elseif tabId == "layout" then LayoutLayoutTab(w)
        elseif tabId == "profiles" then LayoutProfiles(w)
        end

        local curPane = tabPanes[tabId]
        if curPane and curPane.contentHeight then
            scrollChild:SetHeight(curPane.contentHeight)
        end
        scrollFrame:SetVerticalScroll(0)
        if updateScroll then updateScroll() end
    end

    -- Dynamic Reflow on Size Change
    scrollFrame:HookScript("OnSizeChanged", function(self, w, h)
        if w and w > 100 then
            LayoutAllTabs(w)
        end
    end)

    tabsContainer:SetScript("OnSizeChanged", function()
        LayoutTabButtons()
    end)

    parentContainer:HookScript("OnShow", function()
        local w = scrollFrame:GetWidth() or contentWidth or 540
        if not w or w < 100 then w = 540 end
        LayoutAllTabs(w)
        ShowTab(activeTab)
    end)

    LayoutAllTabs(contentWidth)
    ShowTab("general")
end

--[[-----------------------------------------------------------------------------
    Live Refresh
-------------------------------------------------------------------------------]]
function UI:Refresh()
    for _, widget in ipairs(registeredWidgets) do
        if widget.update then
            widget.update()
        end
    end
end

--[[-----------------------------------------------------------------------------
    Standalone Fallback Window (When Master Hub is not loaded)
-------------------------------------------------------------------------------]]
function UI:CreateStandaloneWindow()
    if self.standaloneFrame then return self.standaloneFrame end

    local f = CreateFrame("Frame", ADDON_NAME .. "StandaloneWindow", UIParent, BACKDROP_TEMPLATE)
    f:SetSize(720, 520)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)

    tinsert(UISpecialFrames, ADDON_NAME .. "StandaloneWindow")

    f:SetBackdrop(WINDOW_BACKDROP)
    f:SetBackdropColor(unpack(COLORS.bgSlate))
    f:SetBackdropBorderColor(unpack(COLORS.goldBorder))

    -- Title Bar (Drag Handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -6)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText("|cffffd100" .. FULL_TITLE .. "|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Inset Content Container
    local content = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -38)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    content:SetBackdrop(INSET_BACKDROP)
    content:SetBackdropColor(unpack(COLORS.contentBg))
    content:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    self:BuildOptions(content, false)

    f:Hide()
    self.standaloneFrame = f
    return f
end

function UI:ToggleStandaloneWindow()
    local win = self:CreateStandaloneWindow()
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
    end
end

