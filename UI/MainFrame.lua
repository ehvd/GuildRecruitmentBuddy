local GRB = GuildRecruitmentBuddy
local L = GRB.L

local AceGUI = LibStub("AceGUI-3.0")

-- Tabbed main window. Tabs register themselves with RegisterTab(key, label, build, cleanup):
--   build(container)  fills the AceGUI container when the tab is shown
--   cleanup()         optional, called when the tab content is released
local MainFrame = { tabs = {}, order = {} }
GRB.MainFrame = MainFrame

local FRAME_GLOBAL = "GuildRecruitmentBuddyMainFrame"
local specialFrameAdded = false

function MainFrame:RegisterTab(key, label, build, cleanup)
    if not self.tabs[key] then
        tinsert(self.order, key)
    end
    self.tabs[key] = { label = label, build = build, cleanup = cleanup }
end

function MainFrame:CleanupCurrent()
    local tab = self.currentTab and self.tabs[self.currentTab]
    if tab and tab.cleanup then
        tab.cleanup()
    end
end

function MainFrame:SelectTab(key)
    if not self.tabGroup then return end
    if not self.tabs[key] then key = self.order[1] end
    if key then
        self.tabGroup:SelectTab(key)
    end
end

function MainFrame:Create(key)
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["ADDON_NAME"])
    frame:SetStatusText(GRB.version)
    frame:SetWidth(720)
    frame:SetHeight(540)
    frame:SetLayout("Fill")
    frame:SetCallback("OnClose", function(widget)
        MainFrame:CleanupCurrent()
        MainFrame.currentTab = nil
        MainFrame.frame = nil
        MainFrame.tabGroup = nil
        AceGUI:Release(widget)
    end)

    local tabList = {}
    for _, tabKey in ipairs(self.order) do
        tinsert(tabList, { value = tabKey, text = self.tabs[tabKey].label })
    end

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(tabList)
    tabGroup:SetCallback("OnGroupSelected", function(container, _, group)
        MainFrame:CleanupCurrent()
        container:ReleaseChildren()
        MainFrame.currentTab = group
        MainFrame.tabs[group].build(container)
    end)
    frame:AddChild(tabGroup)

    self.frame = frame
    self.tabGroup = tabGroup

    -- Close with Escape
    _G[FRAME_GLOBAL] = frame.frame
    if not specialFrameAdded then
        tinsert(UISpecialFrames, FRAME_GLOBAL)
        specialFrameAdded = true
    end

    self:SelectTab(key)
end

function MainFrame:Toggle(key)
    if self.frame then
        if key and key ~= self.currentTab and self.tabs[key] then
            self:SelectTab(key)
        else
            self.frame:Hide()
        end
    else
        self:Create(key)
    end
end
