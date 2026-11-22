local WINDOW_WIDTH, WINDOW_HEIGHT = 740, 530
local ROW_HEIGHT = 26

local WINDOW_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
}

local NATIVE_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
}

local C_BG_MAIN = {0.25, 0.25, 0.27, 1.00}
local C_BG_PANEL = {0.12, 0.12, 0.13, 0.92}
local C_BG_HEADER = {0.18, 0.18, 0.20, 1.00}
local C_BORDER = {1.00, 0.82, 0.00, 0.30}
local C_CONTROL_BORDER = {0.42, 0.42, 0.45, 0.75}
local C_SELECTION = {0.76, 0.76, 0.76, 0.85}

local sortByCount = false
local pendingDeleteChar = nil

StaticPopupDialogs["ALTEREGO_DELETE_CHAR"] = {
    text = "Delete saved EverAlts data for %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if pendingDeleteChar and Alterego_DeleteCharacter then
            Alterego_DeleteCharacter(pendingDeleteChar)
            if AlteregoWindow.selectedChar == pendingDeleteChar then
                AlteregoWindow.selectedChar = "ALL"
            end
            pendingDeleteChar = nil
            AlteregoWindow.RefreshSidebar()
            AlteregoWindow.RefreshContent()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- ===== Main Frameless Window =====
local window = CreateFrame("Frame", "EverAltsMainWindow", UIParent, "BackdropTemplate")
window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
window:SetPoint("CENTER")
window:SetMovable(true)
window:EnableMouse(true)
window:SetClampedToScreen(true)
window:SetFrameStrata("HIGH")
window:SetBackdrop(WINDOW_BACKDROP)
window:SetBackdropColor(unpack(C_BG_MAIN))
window:SetBackdropBorderColor(unpack(C_BORDER))
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if AlteregoDB then
        local point, _, relPoint, x, y = self:GetPoint()
        AlteregoDB.windowPos = {
            point = point,
            relPoint = relPoint,
            x = x,
            y = y
        }
    end
end)
window:Hide()
tinsert(UISpecialFrames, "EverAltsMainWindow")

-- ===== Title Bar =====
local titleBar = CreateFrame("Frame", nil, window, "BackdropTemplate")
titleBar:SetPoint("TOPLEFT", 1, -1)
titleBar:SetPoint("TOPRIGHT", -1, -1)
titleBar:SetHeight(32)
titleBar:SetBackdrop(WINDOW_BACKDROP)
titleBar:SetBackdropColor(unpack(C_BG_HEADER))
titleBar:SetBackdropBorderColor(unpack(C_BORDER))

local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
titleIcon:SetSize(18, 18)
titleIcon:SetPoint("LEFT", 10, 0)
titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
titleText:SetText("|cffffd100EverAlts|r  |cffc4c0b9Alt Manager|r")

local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
closeBtn:SetSize(24, 24)
closeBtn:SetPoint("RIGHT", -5, 0)
closeBtn:SetScript("OnClick", function()
    window:Hide()
end)

-- ===== Left Sidebar (Characters + Total Gold) =====
local sidebar = CreateFrame("Frame", nil, window, "BackdropTemplate")
sidebar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, -8)
sidebar:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 9, 9)
sidebar:SetWidth(180)
sidebar:SetBackdrop(NATIVE_BACKDROP)
sidebar:SetBackdropColor(unpack(C_BG_PANEL))
sidebar:SetBackdropBorderColor(unpack(C_BORDER))

local sidebarHeader = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sidebarHeader:SetPoint("TOPLEFT", 10, -8)
sidebarHeader:SetText("|cffffd100CHARACTERS|r")

local sidebarHint = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
sidebarHint:SetPoint("TOPRIGHT", -8, -8)
sidebarHint:SetText("Shift+R-Click: Del")

local sidebarFooter = CreateFrame("Frame", nil, sidebar, "BackdropTemplate")
sidebarFooter:SetPoint("BOTTOMLEFT", 0, 0)
sidebarFooter:SetPoint("BOTTOMRIGHT", 0, 0)
sidebarFooter:SetHeight(30)
sidebarFooter:SetBackdrop(WINDOW_BACKDROP)
sidebarFooter:SetBackdropColor(unpack(C_BG_HEADER))
sidebarFooter:SetBackdropBorderColor(unpack(C_BORDER))

local totalGoldText = sidebarFooter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
totalGoldText:SetPoint("LEFT", 8, 0)
totalGoldText:SetPoint("RIGHT", -8, 0)
totalGoldText:SetJustifyH("RIGHT")

local sidebarScroll = CreateFrame("ScrollFrame", "AlteregoCharScroll", sidebar, "UIPanelScrollFrameTemplate")
sidebarScroll:SetPoint("TOPLEFT", 6, -24)
sidebarScroll:SetPoint("BOTTOMRIGHT", -24, 34)

local sidebarContent = CreateFrame("Frame", nil, sidebarScroll)
sidebarContent:SetSize(147, 1)
sidebarScroll:SetScrollChild(sidebarContent)

-- ===== Right Content Area =====
local contentPanel = CreateFrame("Frame", nil, window)
contentPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
contentPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -9, 9)

-- Top Navigation Bar (Tabs + Sort + Search)
local navBar = CreateFrame("Frame", nil, contentPanel)
navBar:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 0, 0)
navBar:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", 0, 0)
navBar:SetHeight(28)

local tabs = {}
local tabNames = {"Currencies", "Inventory", "Professions"}
local activeTab = 1

local scroll -- forward declare for scroll reset

local function UpdateTabVisuals()
    for i, t in ipairs(tabs) do
        if i == activeTab then
            t:SetButtonState("PUSHED", true)
            t:GetFontString():SetTextColor(1, 1, 1)
        else
            t:SetButtonState("NORMAL")
            t:GetFontString():SetTextColor(0.82, 0.82, 0.82)
        end
    end
end

local function CreateTab(index)
    local tab = CreateFrame("Button", "AlteregoTab" .. index, navBar, "UIPanelButtonTemplate")
    tab:SetSize(88, 26)
    if index == 1 then
        tab:SetPoint("LEFT", navBar, "LEFT", 0, 0)
    else
        tab:SetPoint("LEFT", tabs[index - 1], "RIGHT", 4, 0)
    end

    tab:SetText(tabNames[index])
    tab:SetScript("OnClick", function(self)
        activeTab = index
        UpdateTabVisuals()
        self:ClearFocus()
        if scroll then
            scroll:SetVerticalScroll(0)
        end
        AlteregoWindow.RefreshContent()
    end)

    tabs[index] = tab
    return tab
end

for i = 1, #tabNames do
    CreateTab(i)
end
UpdateTabVisuals()

-- Search Box
local searchBox = CreateFrame("EditBox", "AlteregoSearchBox", navBar, "SearchBoxTemplate")
searchBox:SetSize(165, 22)
searchBox:SetPoint("RIGHT", navBar, "RIGHT", -2, 0)
searchBox:SetAutoFocus(false)
searchBox:SetScript("OnTextChanged", function()
    if scroll then
        scroll:SetVerticalScroll(0)
    end
    AlteregoWindow.RefreshContent()
end)
searchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

-- Sort Toggle Button
local sortBtn = CreateFrame("Button", nil, navBar, "UIPanelButtonTemplate")
sortBtn:SetSize(74, 24)
sortBtn:SetPoint("RIGHT", searchBox, "LEFT", -6, 0)
sortBtn:SetText("Sort: Name")
sortBtn:GetFontString():SetTextColor(1, 1, 1)

sortBtn:SetScript("OnClick", function(self)
    sortByCount = not sortByCount
    self:SetText(sortByCount and "Sort: Qty" or "Sort: Name")
    AlteregoWindow.RefreshContent()
end)

-- Character Info Banner
local charBanner = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
charBanner:SetPoint("TOPLEFT", navBar, "BOTTOMLEFT", 0, -6)
charBanner:SetPoint("TOPRIGHT", navBar, "BOTTOMRIGHT", 0, -6)
charBanner:SetHeight(28)
charBanner:SetBackdrop(WINDOW_BACKDROP)
charBanner:SetBackdropColor(unpack(C_BG_HEADER))
charBanner:SetBackdropBorderColor(unpack(C_BORDER))

local charBannerName = charBanner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
charBannerName:SetPoint("LEFT", 10, 0)

local charBannerGold = charBanner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
charBannerGold:SetPoint("RIGHT", -10, 0)

-- Main Scroll List Panel
local scrollFrame = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
scrollFrame:SetPoint("TOPLEFT", charBanner, "BOTTOMLEFT", 0, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", 0, 0)
scrollFrame:SetBackdrop(NATIVE_BACKDROP)
scrollFrame:SetBackdropColor(unpack(C_BG_PANEL))
scrollFrame:SetBackdropBorderColor(unpack(C_BORDER))
scroll = CreateFrame("ScrollFrame", "AlteregoContentScroll", scrollFrame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 6, -6)
scroll:SetPoint("BOTTOMRIGHT", -26, 6)
local scrollContent = CreateFrame("Frame", nil, scroll)
scrollContent:SetSize(500, 1)
scroll:SetScrollChild(scrollContent)
local emptyText = scrollFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("CENTER")
emptyText:SetText("No entries found.")
emptyText:Hide()
-- ===== Row Factory =====
local rows = {}
local function CreateRow(index)
    local row = CreateFrame("Button", nil, scrollContent)
    row:SetSize(500, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    if index % 2 == 0 then
        row.stripe:SetColorTexture(1, 1, 1, 0.04)
    else
        row.stripe:SetColorTexture(0, 0, 0, 0)
    end
    row.hoverTex = row:CreateTexture(nil, "HIGHLIGHT")
    row.hoverTex:SetAllPoints()
    row.hoverTex:SetColorTexture(0.75, 0.75, 0.75, 0.10)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(19, 19)
    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -135, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.value:SetJustifyH("RIGHT")
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        if IsShiftKeyDown() and self.tooltipData and self.tooltipData.itemID then
            local _, link = GetItemInfo(self.tooltipData.itemID)
            if link then
                ChatEdit_InsertLink(link)
            end
        end
    end)
    row:SetScript("OnEnter", function(self)
        if not self.tooltipData then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.tooltipData.itemID then
            GameTooltip:SetItemByID(self.tooltipData.itemID)
        else
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.tooltipData.title, 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Character:", self.tooltipData.charName, 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine(self.tooltipData.typeLabel, self.tooltipData.value, 0.8, 0.8, 0.8, 0, 1, 0)
            if self.tooltipData.breakdown and #self.tooltipData.breakdown > 0 then
                GameTooltip:AddLine(" ")
                for _, b in ipairs(self.tooltipData.breakdown) do
                    local c = RAID_CLASS_COLORS[b.class] or NORMAL_FONT_COLOR
                    local shortName = b.charKey:match("^([^-]+)") or b.charKey
                    GameTooltip:AddDoubleLine(shortName, tostring(b.amount), c.r, c.g, c.b, 1, 1, 1)
                end
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    rows[index] = row
    return row
end
local function AcquireRow(index)
    return rows[index] or CreateRow(index)
end
-- ===== Sidebar Refresh =====
local charButtons = {}
local function FormatGoldCompact(copper)
    copper = copper or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    return string.format("%dg %ds", gold, silver)
end
local function RefreshSidebar()
    if not AlteregoDB or not AlteregoDB.chars then
        return
    end
    local currentChar = Alterego_GetCurrentCharKey and Alterego_GetCurrentCharKey() or ""
    local keys = {"ALL"}
    local totalCopper = 0
    for k, v in pairs(AlteregoDB.chars) do
        table.insert(keys, k)
        totalCopper = totalCopper + (v.gold or 0)
    end
    table.sort(keys, function(a, b)
        if a == b then
            return false
        end
        if a == "ALL" then
            return true
        end
        if b == "ALL" then
            return false
        end
        if a == currentChar then
            return true
        end
        if b == currentChar then
            return false
        end
        return a < b
    end)
    totalGoldText:SetText("|cffc4c0b9Total:|r " .. C_CurrencyInfo.GetCoinTextureString(totalCopper))
    local i = 1
    for _, key in ipairs(keys) do
        local btn = charButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, sidebarContent, "BackdropTemplate")
            btn:SetSize(147, 32)
            btn:SetPoint("TOPLEFT", sidebarContent, "TOPLEFT", 0, -(i - 1) * 34)
            btn:SetBackdrop(NATIVE_BACKDROP)
            btn:SetBackdropColor(unpack(C_BG_PANEL))
            btn:SetBackdropBorderColor(unpack(C_CONTROL_BORDER))
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn.bar = btn:CreateTexture(nil, "OVERLAY")
            btn.bar:SetWidth(3)
            btn.bar:SetPoint("TOPLEFT", 1, -1)
            btn.bar:SetPoint("BOTTOMLEFT", 1, 1)
            btn.bar:SetColorTexture(unpack(C_SELECTION))
            btn.bar:Hide()
            btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.nameText:SetPoint("TOPLEFT", 8, -4)
            btn.nameText:SetPoint("RIGHT", -6, 0)
            btn.nameText:SetJustifyH("LEFT")
            btn.nameText:SetWordWrap(false)
            btn.subText = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            btn.subText:SetPoint("BOTTOMLEFT", 8, 4)
            btn.subText:SetPoint("RIGHT", -6, 0)
            btn.subText:SetJustifyH("LEFT")
            btn.subText:SetWordWrap(false)
            btn:SetScript("OnEnter", function(self)
                if AlteregoWindow.selectedChar ~= self.charKey then
                    self:SetBackdropColor(unpack(C_BG_HEADER))
                end
            end)
            btn:SetScript("OnLeave", function(self)
                if AlteregoWindow.selectedChar == self.charKey then
                    self:SetBackdropColor(unpack(C_BG_HEADER))
                    self:SetBackdropBorderColor(unpack(C_SELECTION))
                else
                    self:SetBackdropColor(unpack(C_BG_PANEL))
                    self:SetBackdropBorderColor(unpack(C_CONTROL_BORDER))
                end
            end)
            btn:SetScript("OnClick", function(self, button)
                if button == "RightButton" and IsShiftKeyDown() and self.charKey ~= "ALL" then
                    pendingDeleteChar = self.charKey
                    StaticPopup_Show("ALTEREGO_DELETE_CHAR", self.charKey)
                    return
                end
                AlteregoWindow.selectedChar = self.charKey
                if scroll then
                    scroll:SetVerticalScroll(0)
                end
                RefreshSidebar()
                AlteregoWindow.RefreshContent()
            end)
            charButtons[i] = btn
        end
        btn.charKey = key
        local isSelected = (AlteregoWindow.selectedChar == key)
        if key == "ALL" then
            btn.nameText:SetText("|cffffffffAll Characters|r")
            btn.subText:SetText((#keys - 1) .. " alts tracked")
        else
            local charData = AlteregoDB.chars[key]
            local c = (charData and RAID_CLASS_COLORS[charData.class]) or NORMAL_FONT_COLOR
            local shortName = key:match("^([^-]+)") or key
            local activePrefix = (key == currentChar) and "|cffbfbfbf•|r " or ""
            btn.nameText:SetText(activePrefix .. shortName)
            btn.nameText:SetTextColor(c.r, c.g, c.b)
            btn.subText:SetText(string.format("Lvl %d  •  %s", charData.level or 1, FormatGoldCompact(charData.gold)))
        end
        if isSelected then
            btn:SetBackdropColor(unpack(C_BG_HEADER))
            btn:SetBackdropBorderColor(unpack(C_SELECTION))
            btn.bar:Show()
        else
            btn:SetBackdropColor(unpack(C_BG_PANEL))
            btn:SetBackdropBorderColor(unpack(C_CONTROL_BORDER))
            btn.bar:Hide()
        end
        btn:Show()
        i = i + 1
    end
    for j = i, #charButtons do
        charButtons[j]:Hide()
    end
    sidebarContent:SetHeight(math.max(1, (i - 1) * 34))
end
-- ===== Content Refresh =====
local function GetFilterText()
    local text = searchBox:GetText()
    if text and text ~= "" then
        return string.lower(text)
    end
    return nil
end
local function BuildAggregatedData()
    local agg = {
        currencies = {},
        bags = {},
        bank = {},
        professions = {},
        gold = 0,
        isAll = true
    }
    for charKey, data in pairs(AlteregoDB.chars) do
        local shortName = charKey:match("^([^-]+)") or charKey
        local c = RAID_CLASS_COLORS[data.class] or NORMAL_FONT_COLOR
        local hex = string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
        local coloredAlt = hex .. shortName .. "|r"
        agg.gold = agg.gold + (data.gold or 0)
        for id, cur in pairs(data.currencies or {}) do
            local key = id
            if not agg.currencies[key] then
                agg.currencies[key] = {
                    name = cur.name,
                    quantity = 0,
                    icon = cur.icon,
                    breakdown = {}
                }
            end
            agg.currencies[key].quantity = agg.currencies[key].quantity + (cur.quantity or 0)
            table.insert(agg.currencies[key].breakdown, {
                charKey = charKey,
                class = data.class,
                amount = cur.quantity or 0
            })
        end
        for itemID, item in pairs(data.bags or {}) do
            if not agg.bags[itemID] then
                agg.bags[itemID] = {
                    itemID = itemID,
                    name = item.name,
                    icon = item.icon,
                    quality = item.quality,
                    count = 0
                }
            end
            agg.bags[itemID].count = agg.bags[itemID].count + (item.count or 0)
        end
        for itemID, item in pairs(data.bank or {}) do
            if not agg.bank[itemID] then
                agg.bank[itemID] = {
                    itemID = itemID,
                    name = item.name,
                    icon = item.icon,
                    quality = item.quality,
                    count = 0
                }
            end
            agg.bank[itemID].count = agg.bank[itemID].count + (item.count or 0)
        end
        for profName, p in pairs(data.professions or {}) do
            local label = profName .. " (" .. coloredAlt .. ")"
            agg.professions[label] = p
        end
    end
    return agg
end
local function RenderCurrencies(data, filter)
    local entries = {}
    for _, c in pairs(data.currencies or {}) do
        if not filter or string.find(string.lower(c.name), filter, 1, true) then
            if c.breakdown then
                table.sort(c.breakdown, function(a, b)
                    return a.amount > b.amount
                end)
            end
            table.insert(entries, c)
        end
    end
    table.sort(entries, function(a, b)
        if sortByCount and a.quantity ~= b.quantity then
            return a.quantity > b.quantity
        end
        return a.name < b.name
    end)
    return entries, function(c)
        return c.name, "|cffffffff" .. tostring(c.quantity) .. "|r", c.icon, "Amount:", nil, c.breakdown
    end
end
local function RenderInventory(data, filter)
    local merged = {}
    for itemID, item in pairs(data.bags or {}) do
        merged[itemID] = {
            itemID = itemID,
            name = item.name,
            icon = item.icon,
            quality = item.quality,
            bags = item.count,
            bank = 0
        }
    end
    for itemID, item in pairs(data.bank or {}) do
        if merged[itemID] then
            merged[itemID].bank = item.count
        else
            merged[itemID] = {
                itemID = itemID,
                name = item.name,
                icon = item.icon,
                quality = item.quality,
                bags = 0,
                bank = item.count
            }
        end
    end
    local entries = {}
    for _, item in pairs(merged) do
        if not filter or string.find(string.lower(item.name), filter, 1, true) then
            item.total = item.bags + item.bank
            table.insert(entries, item)
        end
    end
    table.sort(entries, function(a, b)
        if sortByCount and a.total ~= b.total then
            return a.total > b.total
        end
        return a.name < b.name
    end)
    return entries, function(item)
        local qColor = (item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality])
        local displayName = qColor and (qColor.hex .. item.name .. "|r") or item.name
        local val = string.format("|cffffffffx%d|r |cffc4c0b9(%d / %d)|r", item.total, item.bags, item.bank)
        return displayName, val, item.icon, "Total (Bag/Bank):", item.itemID, nil
    end
end
local function RenderProfessions(data, filter)
    local entries = {}
    local profNames = {}
    for name in pairs(data.professions or {}) do
        table.insert(profNames, name)
    end
    table.sort(profNames)
    for _, name in ipairs(profNames) do
        local p = data.professions[name]
        local profMatches = not filter or string.find(string.lower(name), filter, 1, true)
        local matchingRecipes = {}
        for _, r in pairs(p.recipes or {}) do
            if not filter or string.find(string.lower(r.name), filter, 1, true) then
                table.insert(matchingRecipes, r)
            end
        end
        table.sort(matchingRecipes, function(a, b)
            return a.name < b.name
        end)
        if profMatches or #matchingRecipes > 0 then
            table.insert(entries, {
                name = "|cffffd100" .. name .. "|r",
                value = string.format("|cffffffff%d / %d|r", p.skill or 0, p.max or 0),
                icon = p.icon,
                typeLabel = "Skill:"
            })
            for _, r in ipairs(matchingRecipes) do
                table.insert(entries, {
                    name = "   " .. r.name,
                    value = "|cffc4c0b9Recipe|r",
                    icon = r.icon,
                    typeLabel = name .. ":",
                    itemID = r.itemID
                })
            end
        end
    end
    return entries, function(e)
        return e.name, e.value, e.icon, e.typeLabel, e.itemID, nil
    end
end
function AlteregoWindow_Refresh()
    if not AlteregoDB or not AlteregoDB.chars then
        return
    end
    if not AlteregoWindow.selectedChar or
        (AlteregoWindow.selectedChar ~= "ALL" and not AlteregoDB.chars[AlteregoWindow.selectedChar]) then
        AlteregoWindow.selectedChar = "ALL"
        RefreshSidebar()
    end
    local isAll = (AlteregoWindow.selectedChar == "ALL")
    local data = isAll and BuildAggregatedData() or AlteregoDB.chars[AlteregoWindow.selectedChar]
    if not data then
        return
    end
    if isAll then
        charBannerName:SetText("|cffffd100All Characters|r  |cffc4c0b9(Account Summary)|r")
        charBannerGold:SetText(C_CurrencyInfo.GetCoinTextureString(data.gold or 0))
    else
        local c = RAID_CLASS_COLORS[data.class] or NORMAL_FONT_COLOR
        local hex = string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
        local seenStr = Alterego_FormatTimeAgo and Alterego_FormatTimeAgo(data.lastSeen) or ""
        charBannerName:SetText(string.format("%s%s|r  |cffc4c0b9Level %d  •  Seen: %s|r", hex,
            AlteregoWindow.selectedChar, data.level or 1, seenStr))
        charBannerGold:SetText(C_CurrencyInfo.GetCoinTextureString(data.gold or 0))
    end
    local filter = GetFilterText()
    local entries, formatter
    if activeTab == 1 then
        entries, formatter = RenderCurrencies(data, filter)
    elseif activeTab == 2 then
        entries, formatter = RenderInventory(data, filter)
    else
        entries, formatter = RenderProfessions(data, filter)
    end
    local i = 1
    for _, entry in ipairs(entries) do
        local row = AcquireRow(i)
        local name, value, icon, typeLabel, itemID, breakdown = formatter(entry)
        row.name:SetText(name)
        row.value:SetText(value)
        row.icon:SetTexture(icon or 134400)
        row.tooltipData = {
            title = name,
            charName = isAll and "All Characters" or AlteregoWindow.selectedChar,
            typeLabel = typeLabel,
            value = value,
            itemID = itemID,
            breakdown = breakdown
        }
        row:Show()
        i = i + 1
    end
    emptyText:SetShown(i == 1)
    for j = i, #rows do
        rows[j]:Hide()
    end
    scrollContent:SetHeight(math.max(1, (i - 1) * ROW_HEIGHT))
end
-- ===== Public API =====
AlteregoWindow = {
    selectedChar = "ALL",
    RefreshSidebar = RefreshSidebar,
    RefreshContent = function()
        AlteregoWindow_Refresh()
    end,
    RestorePosition = function()
        if AlteregoDB and AlteregoDB.windowPos then
            local pos = AlteregoDB.windowPos
            window:ClearAllPoints()
            window:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        end
    end,
    Toggle = function()
        if window:IsShown() then
            window:Hide()
        else
            RefreshSidebar()
            AlteregoWindow_Refresh()
            window:Show()
        end
    end
}
