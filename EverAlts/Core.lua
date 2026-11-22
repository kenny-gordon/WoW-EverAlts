local addonName, ns = ...
local bankOpen = false
local pendingItems = {}

local frame = CreateFrame("Frame")
local events = {"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED",
                "BANKFRAME_CLOSED", "CURRENCY_DISPLAY_UPDATE", "ITEM_DATA_LOAD_RESULT", "TRADE_SKILL_SHOW",
                "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "CRAFT_SHOW", "CRAFT_UPDATE"}

for _, ev in ipairs(events) do
    pcall(frame.RegisterEvent, frame, ev)
end

local function SafeCall(func, ...)
    if not func then
        return nil
    end
    local ok, a, b, c, d, e, f = pcall(func, ...)
    if ok then
        return a, b, c, d, e, f
    end
    return nil
end

function Alterego_GetCurrentCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

function Alterego_FormatTimeAgo(timestamp)
    if not timestamp then
        return "Unknown"
    end
    local diff = math.max(0, time() - timestamp)
    if diff < 60 then
        return "Just now"
    end
    if diff < 3600 then
        return math.floor(diff / 60) .. "m ago"
    end
    if diff < 86400 then
        return math.floor(diff / 3600) .. "h ago"
    end
    return math.floor(diff / 86400) .. "d ago"
end

function Alterego_DeleteCharacter(charKey)
    if not AlteregoDB or not AlteregoDB.chars or not AlteregoDB.chars[charKey] then
        return false
    end
    AlteregoDB.chars[charKey] = nil
    if AlteregoDB.craftableBy then
        for itemID, crafters in pairs(AlteregoDB.craftableBy) do
            crafters[charKey] = nil
            if not next(crafters) then
                AlteregoDB.craftableBy[itemID] = nil
            end
        end
    end
    return true
end

local function ResolveItemInfo(itemID)
    local name, _, quality = SafeCall(GetItemInfo, itemID)
    if not name and C_Item and C_Item.GetItemNameByID then
        name = SafeCall(C_Item.GetItemNameByID, itemID)
    end
    if not name then
        pendingItems[itemID] = true
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
    return name or ("Item " .. itemID), quality
end

local function BackfillItemData(itemID)
    local name, _, quality = SafeCall(GetItemInfo, itemID)
    if not name or not AlteregoDB or not AlteregoDB.chars then
        return
    end

    local updated = false
    for _, data in pairs(AlteregoDB.chars) do
        if data.bags and data.bags[itemID] then
            data.bags[itemID].name = name
            data.bags[itemID].quality = quality or data.bags[itemID].quality
            updated = true
        end
        if data.bank and data.bank[itemID] then
            data.bank[itemID].name = name
            data.bank[itemID].quality = quality or data.bank[itemID].quality
            updated = true
        end
    end

    if updated and AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
        AlteregoWindow.RefreshContent()
    end
end

local function ScanContainer(bag, targetTable)
    local numSlots = SafeCall(C_Container.GetContainerNumSlots, bag) or 0
    for slot = 1, numSlots do
        local info = SafeCall(C_Container.GetContainerItemInfo, bag, slot)
        if type(info) == "table" and info.itemID then
            local entry = targetTable[info.itemID]
            if entry then
                entry.count = entry.count + (info.stackCount or 1)
            else
                local name, quality = ResolveItemInfo(info.itemID)
                targetTable[info.itemID] = {
                    itemID = info.itemID,
                    name = name,
                    count = info.stackCount or 1,
                    icon = info.iconFileID or 134400,
                    quality = info.quality or quality or 1
                }
            end
        end
    end
end

local function CollectBags()
    local items = {}
    for bag = 0, NUM_BAG_SLOTS do
        ScanContainer(bag, items)
    end
    return items
end

local function CollectBank()
    local items = {}
    ScanContainer(BANK_CONTAINER, items)
    local bankBags = NUM_BANKBAGSLOTS or 7
    for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + bankBags do
        ScanContainer(bag, items)
    end
    return items
end

local function CollectCurrencies()
    local currencies = {}
    local size = SafeCall(C_CurrencyInfo.GetCurrencyListSize) or 0
    for i = 1, size do
        local info = SafeCall(C_CurrencyInfo.GetCurrencyListInfo, i)
        if type(info) == "table" and not info.isHeader then
            local qty = tonumber(info.quantity)
            if qty and qty > 0 then
                local id = info.currencyTypesID or info.currencyID or info.name
                currencies[id] = {
                    name = info.name or tostring(id),
                    quantity = qty,
                    icon = info.iconFileID or 134400
                }
            end
        end
    end
    return currencies
end

local function CollectProfessions(existingProfs)
    local profs = existingProfs or {}
    local p1, p2, arch, fish, cook, firstAid = GetProfessions()
    local indices = {p1, p2, arch, fish, cook, firstAid}

    for _, idx in pairs(indices) do
        if idx then
            local name, icon, skillLevel, maxLevel = GetProfessionInfo(idx)
            if name then
                profs[name] = profs[name] or {
                    recipes = {}
                }
                profs[name].skill = tonumber(skillLevel) or 0
                profs[name].max = tonumber(maxLevel) or 0
                profs[name].icon = icon or 134400
            end
        end
    end
    return profs
end

local function ClearCraftableProfession(charKey, profName)
    for itemID, crafters in pairs(AlteregoDB.craftableBy) do
        if crafters[charKey] == profName then
            crafters[charKey] = nil
            if not next(crafters) then
                AlteregoDB.craftableBy[itemID] = nil
            end
        end
    end
end

local function ScanOpenProfession()
    if not AlteregoDB then
        return
    end
    AlteregoDB.chars = AlteregoDB.chars or {}
    AlteregoDB.craftableBy = AlteregoDB.craftableBy or {}
    local charKey = Alterego_GetCurrentCharKey()
    local data = AlteregoDB.chars[charKey]
    if not data then
        return
    end
    data.professions = data.professions or {}

    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local profInfo = SafeCall(C_TradeSkillUI.GetChildProfessionInfo)
        local profName = profInfo and profInfo.professionName
        local recipeIDs = SafeCall(C_TradeSkillUI.GetAllRecipeIDs)
        if profName and recipeIDs then
            data.professions[profName] = data.professions[profName] or {
                skill = profInfo.skillLevel or 0,
                max = profInfo.maxSkillLevel or 0,
                icon = 134400,
                recipes = {}
            }
            data.professions[profName].skill = profInfo.skillLevel or data.professions[profName].skill
            data.professions[profName].max = profInfo.maxSkillLevel or data.professions[profName].max

            data.professions[profName].recipes = data.professions[profName].recipes or {}
            local recipesTable = data.professions[profName].recipes
            ClearCraftableProfession(charKey, profName)
            wipe(recipesTable)

            for _, recipeID in ipairs(recipeIDs) do
                local rInfo = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
                if rInfo and rInfo.learned then
                    local outData = SafeCall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
                    local outItemID = outData and outData.itemID

                    recipesTable[recipeID] = {
                        recipeID = recipeID,
                        name = rInfo.name or ("Recipe " .. recipeID),
                        icon = rInfo.icon or 134400,
                        itemID = outItemID
                    }

                    if outItemID then
                        AlteregoDB.craftableBy[outItemID] = AlteregoDB.craftableBy[outItemID] or {}
                        AlteregoDB.craftableBy[outItemID][charKey] = profName
                    end
                end
            end

            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshContent()
            end
            return
        end
    end

    if GetTradeSkillLine and GetNumTradeSkills then
        local profName, skillLevel, maxSkillLevel = SafeCall(GetTradeSkillLine)
        if profName and profName ~= "UNKNOWN" then
            data.professions[profName] = data.professions[profName] or {
                skill = skillLevel or 0,
                max = maxSkillLevel or 0,
                icon = 134400,
                recipes = {}
            }
            data.professions[profName].skill = skillLevel or data.professions[profName].skill
            data.professions[profName].max = maxSkillLevel or data.professions[profName].max

            data.professions[profName].recipes = data.professions[profName].recipes or {}
            local recipesTable = data.professions[profName].recipes
            ClearCraftableProfession(charKey, profName)
            wipe(recipesTable)

            local numSkills = SafeCall(GetNumTradeSkills) or 0
            for i = 1, numSkills do
                local recipeName, skillType = SafeCall(GetTradeSkillInfo, i)
                if recipeName and skillType ~= "header" and skillType ~= "subheader" then
                    local itemLink = SafeCall(GetTradeSkillItemLink, i)
                    local recipeLink = SafeCall(GetTradeSkillRecipeLink, i)
                    local outItemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
                    local recipeID = (recipeLink and tonumber(recipeLink:match("enchant:(%d+)"))) or i
                    local icon = SafeCall(GetTradeSkillIcon, i) or 134400

                    recipesTable[recipeID] = {
                        recipeID = recipeID,
                        name = recipeName,
                        icon = icon,
                        itemID = outItemID
                    }

                    if outItemID then
                        AlteregoDB.craftableBy[outItemID] = AlteregoDB.craftableBy[outItemID] or {}
                        AlteregoDB.craftableBy[outItemID][charKey] = profName
                    end
                end
            end

            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshContent()
            end
            return
        end
    end

    if GetCraftDisplaySkillLine and GetNumCrafts then
        local profName, skillLevel, maxSkillLevel = SafeCall(GetCraftDisplaySkillLine)
        if profName and profName ~= "UNKNOWN" then
            data.professions[profName] = data.professions[profName] or {
                skill = skillLevel or 0,
                max = maxSkillLevel or 0,
                icon = 134400,
                recipes = {}
            }
            data.professions[profName].recipes = data.professions[profName].recipes or {}
            local recipesTable = data.professions[profName].recipes
            ClearCraftableProfession(charKey, profName)
            wipe(recipesTable)
            local numCrafts = SafeCall(GetNumCrafts) or 0
            for i = 1, numCrafts do
                local craftName, _, craftType = SafeCall(GetCraftInfo, i)
                if craftName and craftType ~= "header" and craftType ~= "subheader" then
                    local itemLink = SafeCall(GetCraftItemLink, i)
                    local outItemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
                    local icon = SafeCall(GetCraftIcon, i) or 134400
                    recipesTable[i] = {
                        recipeID = i,
                        name = craftName,
                        icon = icon,
                        itemID = outItemID
                    }
                    if outItemID then
                        AlteregoDB.craftableBy[outItemID] = AlteregoDB.craftableBy[outItemID] or {}
                        AlteregoDB.craftableBy[outItemID][charKey] = profName
                    end
                end
            end
            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshContent()
            end
        end
    end
end
local function CollectAll()
    local charKey = Alterego_GetCurrentCharKey()
    AlteregoDB.chars[charKey] = AlteregoDB.chars[charKey] or {}
    local data = AlteregoDB.chars[charKey]
    data.class = select(2, UnitClass("player"))
    data.level = UnitLevel("player")
    data.gold = GetMoney()
    data.currencies = CollectCurrencies()
    data.bags = CollectBags()
    data.bank = data.bank or {}
    data.professions = CollectProfessions(data.professions)
    data.lastSeen = time()
end
frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == addonName then
        AlteregoDB = AlteregoDB or {
            chars = {},
            craftableBy = {}
        }
        AlteregoDB.chars = AlteregoDB.chars or {}
        AlteregoDB.craftableBy = AlteregoDB.craftableBy or {}
        AlteregoDB.minimap = AlteregoDB.minimap or {
            hide = false,
            angle = 220
        }
        if AlteregoWindow and AlteregoWindow.RestorePosition then
            AlteregoWindow.RestorePosition()
        end
        if AlteregoMinimap and AlteregoMinimap.UpdatePosition then
            AlteregoMinimap.UpdatePosition()
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            CollectAll()
            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshSidebar()
                AlteregoWindow.RefreshContent()
            end
        end)
    elseif event == "PLAYER_MONEY" then
        local data = AlteregoDB and AlteregoDB.chars[Alterego_GetCurrentCharKey()]
        if data then
            data.gold = GetMoney()
            data.lastSeen = time()
            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshSidebar()
                AlteregoWindow.RefreshContent()
            end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        local data = AlteregoDB and AlteregoDB.chars[Alterego_GetCurrentCharKey()]
        if data then
            data.bags = CollectBags()
            data.gold = GetMoney()
            data.lastSeen = time()
            if bankOpen then
                data.bank = CollectBank()
            end
            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshSidebar()
                AlteregoWindow.RefreshContent()
            end
        end
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        local data = AlteregoDB and AlteregoDB.chars[Alterego_GetCurrentCharKey()]
        if data then
            data.bank = CollectBank()
            data.lastSeen = time()
            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshContent()
            end
        end
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        local data = AlteregoDB and AlteregoDB.chars[Alterego_GetCurrentCharKey()]
        if data then
            data.currencies = CollectCurrencies()
            data.lastSeen = time()
            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshContent()
            end
        end
    elseif event == "ITEM_DATA_LOAD_RESULT" and arg1 and arg2 and pendingItems[arg1] then
        pendingItems[arg1] = nil
        BackfillItemData(arg1)
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event ==
        "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
        C_Timer.After(0.1, ScanOpenProfession)
    end
end)
