local addonName, ns = ...

local function AddAlteregoTooltip(tooltip, itemID)
    if tooltip ~= GameTooltip or not itemID or not AlteregoDB or not AlteregoDB.chars then return end

    local matches = {}
    local grandTotal = 0

    for charKey, data in pairs(AlteregoDB.chars) do
        local bagCount = (data.bags and data.bags[itemID] and data.bags[itemID].count) or 0
        local bankCount = (data.bank and data.bank[itemID] and data.bank[itemID].count) or 0
        local total = bagCount + bankCount

        if total > 0 then
            grandTotal = grandTotal + total
            table.insert(matches, {
                charKey = charKey,
                class = data.class,
                bags = bagCount,
                bank = bankCount,
                total = total,
            })
        end
    end

    table.sort(matches, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.charKey < b.charKey
    end)

    local addedSpace = false
    if #matches > 0 then
        tooltip:AddLine(" ")
        addedSpace = true
        for _, m in ipairs(matches) do
            local c = RAID_CLASS_COLORS[m.class] or NORMAL_FONT_COLOR
            local shortName = m.charKey:match("^([^-]+)") or m.charKey
            tooltip:AddDoubleLine(
                shortName,
                string.format("%d (Bags: %d, Bank: %d)", m.total, m.bags, m.bank),
                c.r, c.g, c.b, 1, 1, 1
            )
        end
        if #matches > 1 then
            tooltip:AddDoubleLine("Total:", tostring(grandTotal), 0.7, 0.75, 0.85, 1, 0.82, 0)
        end
    end

    local crafters = AlteregoDB.craftableBy and AlteregoDB.craftableBy[itemID]
    if crafters then
        local list = {}
        for charKey, profName in pairs(crafters) do
            local data = AlteregoDB.chars[charKey]
            local c = (data and RAID_CLASS_COLORS[data.class]) or NORMAL_FONT_COLOR
            local hex = string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
            local shortName = charKey:match("^([^-]+)") or charKey
            table.insert(list, hex .. shortName .. "|r (" .. profName .. ")")
        end
        table.sort(list)

        if #list > 0 then
            if not addedSpace then tooltip:AddLine(" ") end
            tooltip:AddLine("|cffffd100Craftable by:|r " .. table.concat(list, ", "), 1, 1, 1, true)
        end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if data and data.id then
            AddAlteregoTooltip(tooltip, data.id)
        end
    end)
else
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local _, link = tooltip:GetItem()
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then AddAlteregoTooltip(tooltip, itemID) end
        end
    end)
end
