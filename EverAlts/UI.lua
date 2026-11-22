-- ===== Standalone Draggable Minimap Button =====
local minimapBtn = CreateFrame("Button", "EverAltsMinimapButton", Minimap)
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:EnableMouse(true)
minimapBtn:SetMovable(true)
minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local overlay = minimapBtn:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
bg:SetSize(20, 20)
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetPoint("TOPLEFT", 7, -5)

local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
icon:SetSize(18, 18)
icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:SetPoint("TOPLEFT", 7, -6)

local function UpdateMinimapButtonPosition()
    local angle = (AlteregoDB and AlteregoDB.minimap and AlteregoDB.minimap.angle) or 220
    local rad = math.rad(angle)
    local radius = (Minimap:GetWidth() / 2) + 5
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)

    if AlteregoDB and AlteregoDB.minimap and AlteregoDB.minimap.hide then
        minimapBtn:Hide()
    else
        minimapBtn:Show()
    end
end

minimapBtn:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        if AlteregoDB then
            AlteregoDB.minimap = AlteregoDB.minimap or {}
            AlteregoDB.minimap.angle = angle
        end
        UpdateMinimapButtonPosition()
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

minimapBtn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
        if AlteregoWindow and AlteregoWindow.Toggle then
            AlteregoWindow.Toggle()
        end
    elseif button == "RightButton" and AlteregoDB and AlteregoDB.chars then
        local total = 0
        for _, d in pairs(AlteregoDB.chars) do total = total + (d.gold or 0) end
        print("|cff3f8cf2EverAlts Total Gold:|r " .. C_CurrencyInfo.GetCoinTextureString(total))
    end
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffffffffEverAlts|r |cff778899v0.0.1|r")
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left-Click:", "Toggle Window", 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right-Click:", "Print Total Gold", 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Drag:", "Move Button", 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

AlteregoMinimap = {
    UpdatePosition = UpdateMinimapButtonPosition,
}

-- ===== Slash Commands =====
SLASH_EVERALTS1 = "/everalts"
SLASH_EVERALTS2 = "/ea"
SLASH_EVERALTS3 = "/alterego"
SLASH_EVERALTS4 = "/ae"
SlashCmdList["EVERALTS"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if cmd == "" then
        if AlteregoWindow and AlteregoWindow.Toggle then
            AlteregoWindow.Toggle()
        end
    elseif cmd == "minimap" then
        AlteregoDB.minimap = AlteregoDB.minimap or { hide = false, angle = 220 }
        AlteregoDB.minimap.hide = not AlteregoDB.minimap.hide
        UpdateMinimapButtonPosition()
        print("|cff3f8cf2EverAlts:|r Minimap button " .. (AlteregoDB.minimap.hide and "|cffff5555hidden|r." or "|cff55ff55shown|r."))
    elseif cmd == "delete" and arg ~= "" then
        if Alterego_DeleteCharacter and Alterego_DeleteCharacter(arg) then
            print("|cff3f8cf2EverAlts:|r Deleted data for |cffffd100" .. arg .. "|r.")
            if AlteregoWindow and EverAltsMainWindow and EverAltsMainWindow:IsShown() then
                AlteregoWindow.RefreshSidebar()
                AlteregoWindow.RefreshContent()
            end
        else
            print("|cffff5555EverAlts:|r Character '" .. arg .. "' not found (use Name-Realm).")
        end
    else
        print("|cff3f8cf2=== EverAlts Commands ===|r")
        print("  |cffffd100/ea|r - Toggle main window")
        print("  |cffffd100/ea minimap|r - Toggle minimap icon")
        print("  |cffffd100/ea delete Name-Realm|r - Remove a character")
    end
end
