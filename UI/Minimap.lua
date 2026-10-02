local ADDON_NAME = ...
local GRB = GuildRecruitmentBuddy
local L = GRB.L

local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

local menuFrame = CreateFrame("Frame", "GuildRecruitmentBuddyMenu", UIParent, "UIDropDownMenuTemplate")

local function ShowMenu()
    local menu = {
        { text = L["ADDON_NAME"], isTitle = true, notCheckable = true },
        { text = L["Open window"], notCheckable = true, func = function() GRB:ToggleMainWindow() end },
        {
            text = L["Auto invite (ginv)"],
            checked = function() return GRB:IsInviteEnabled() end,
            keepShownOnClick = true,
            func = function() GRB:SetInviteEnabled(not GRB:IsInviteEnabled()) end,
        },
        {
            text = L["Interval broadcasting"],
            checked = function() return GRB.Broadcast:IsActive() end,
            keepShownOnClick = true,
            func = function() GRB.Broadcast:SetActive(not GRB.Broadcast:IsActive()) end,
        },
        { text = L["Settings"], notCheckable = true, func = function() GRB:OpenConfig() end },
    }
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
end

local launcher = LDB:NewDataObject(ADDON_NAME, {
    type = "launcher",
    text = L["ADDON_NAME"],
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    OnClick = function(_, button)
        if button == "RightButton" then
            ShowMenu()
        else
            GRB:ToggleMainWindow()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine(L["ADDON_NAME"] .. " " .. GRB.version)
        tooltip:AddLine(L["Left-click: open window"], 1, 1, 1)
        tooltip:AddLine(L["Right-click: menu"], 1, 1, 1)
    end,
})

function GRB:UpdateMinimapButton()
    if self.db.profile.minimap.hide then
        DBIcon:Hide(ADDON_NAME)
    else
        DBIcon:Show(ADDON_NAME)
    end
end

function GRB:SetupMinimapButton()
    DBIcon:Register(ADDON_NAME, launcher, self.db.profile.minimap)
end
