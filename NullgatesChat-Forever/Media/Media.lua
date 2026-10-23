local addonName, BFC = ...
BFC = BFC or {}

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local mediaPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local fontPath = mediaPath .. "Fonts\\"

-- Default Font Constants
BFC.DEFAULT_FONT_NAME = "Nata Sans Regular"
BFC.DEFAULT_FONT_PATH = fontPath .. "NataSans-Regular.ttf"

BFC.DEFAULT_HEADER_FONT_NAME = "Nata Sans Bold"
BFC.DEFAULT_HEADER_FONT_PATH = fontPath .. "NataSans-Bold.ttf"

-- Register Nata Sans Family (Primary Typography)
if LSM then
    LSM:Register("font", "Nata Sans Regular", fontPath .. "NataSans-Regular.ttf")
    LSM:Register("font", "Nata Sans Bold", fontPath .. "NataSans-Bold.ttf")
    LSM:Register("font", "Nata Sans Medium", fontPath .. "NataSans-Medium.ttf")
    LSM:Register("font", "NullgateUI Regular", fontPath .. "NataSans-Regular.ttf")
    LSM:Register("font", "NullgateUI Bold", fontPath .. "NataSans-Bold.ttf")
end

if LSM then
    -- Register Orbitron Family (Futuristic / Tech Display)
    LSM:Register("font", "Orbitron Regular", fontPath .. "Orbitron-Regular.ttf")
    LSM:Register("font", "Orbitron Medium", fontPath .. "Orbitron-Medium.ttf")
    LSM:Register("font", "Orbitron Bold", fontPath .. "Orbitron-Bold.ttf")

    -- Register Roboto Condensed Family (Compact Sans-Serif)
    LSM:Register("font", "Roboto Condensed Regular", fontPath .. "RobotoCondensed-Regular.ttf")
    LSM:Register("font", "Roboto Condensed Medium", fontPath .. "RobotoCondensed-Medium.ttf")
    LSM:Register("font", "Roboto Condensed Bold", fontPath .. "RobotoCondensed-Bold.ttf")

    -- Register Status Bar Textures
    LSM:Register("statusbar", "NullgateFlat", "Interface\\Buttons\\WHITE8x8")
    LSM:Register("statusbar", "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar")
    LSM:Register("statusbar", "Blizzard Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
end

-- Media Fetch Helpers with safety fallbacks
function BFC:FetchFont(fontName)
    local fallback = BFC.DEFAULT_FONT_PATH
    if not fontName or fontName == "" then
        fontName = BFC.DEFAULT_FONT_NAME
    end

    if type(fontName) == "string" and (fontName:find("%.ttf$") or fontName:find("%.otf$") or fontName:find("\\") or fontName:find("/")) then
        return fontName
    end

    if LSM then
        local font = LSM:Fetch("font", fontName, true)
        if font and font ~= "" then
            return font
        end

        local def = LSM:Fetch("font", BFC.DEFAULT_FONT_NAME, true)
        if def and def ~= "" then
            return def
        end
    end

    return fallback
end

function BFC:FetchHeaderFont(fontName)
    local fallback = BFC.DEFAULT_HEADER_FONT_PATH
    if not fontName or fontName == "" then
        fontName = BFC.DEFAULT_HEADER_FONT_NAME
    end

    if type(fontName) == "string" and (fontName:find("%.ttf$") or fontName:find("%.otf$") or fontName:find("\\") or fontName:find("/")) then
        return fontName
    end

    if LSM then
        local font = LSM:Fetch("font", fontName, true)
        if font and font ~= "" then
            return font
        end

        local def = LSM:Fetch("font", BFC.DEFAULT_HEADER_FONT_NAME, true)
        if def and def ~= "" then
            return def
        end
    end

    return fallback
end

function BFC:FetchStatusbar(barName)
    if not barName or barName == "" then
        barName = "NullgateFlat"
    end

    if LSM then
        local bar = LSM:Fetch("statusbar", barName, true)
        if bar and bar ~= "" then
            return bar
        end
    end

    return "Interface\\Buttons\\WHITE8x8"
end
