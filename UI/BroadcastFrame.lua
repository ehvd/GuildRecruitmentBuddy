local GRB = GuildRecruitmentBuddy
local L = GRB.L

-- Small movable popup shown while a channel broadcast is ready. Clicking Send (or pressing the keybind /
-- using `/grb send`) is the hardware event that SendChatMessage to a channel requires.
local BroadcastFrame = {}
GRB.BroadcastFrame = BroadcastFrame

local frame

local BUTTON_WIDTH = 150
local BUTTON_HEIGHT = 24
local GAP = 10          -- space between buttons and between button rows
local BOTTOM_PADDING = 28

local function CreateButton(text, onClick)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Create()
    frame = CreateFrame("Frame", "GuildRecruitmentBuddyBroadcastFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 196)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -290)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -26)
    frame.title:SetText(L["Broadcast ready"])

    -- Cogwheel in the top right corner: opens the Broadcast tab of the main window
    frame.settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.settings:SetSize(24, 24)
    frame.settings:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -20)
    local cog = frame.settings:CreateTexture(nil, "OVERLAY")
    cog:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    cog:SetSize(16, 16)
    cog:SetPoint("CENTER")
    frame.settings:SetScript("OnClick", function()
        GRB.MainFrame:Open("Broadcast")
    end)
    frame.settings:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Broadcast settings"])
        GameTooltip:Show()
    end)
    frame.settings:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", frame.title, "BOTTOM", 0, -16)
    frame.text:SetWidth(310)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.hint:SetPoint("TOP", frame.text, "BOTTOM", 0, -8)
    frame.hint:SetWidth(310)

    -- Row 1: send or skip
    local rowOne = BOTTOM_PADDING + BUTTON_HEIGHT + GAP
    frame.send = CreateButton(L["Send"], function()
        GRB.Broadcast:SendNext()
    end)
    frame.send:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -GAP / 2, rowOne)

    frame.skip = CreateButton(L["Skip"], function()
        GRB.Broadcast:SkipNext()
    end)
    frame.skip:SetPoint("BOTTOMLEFT", frame, "BOTTOM", GAP / 2, rowOne)

    -- Row 2: switch off this broadcast, or the whole feature
    frame.disableEntry = CreateButton(L["Disable this broadcast"], function()
        if frame.entryId then
            GRB.Broadcast:UpdateEntry(frame.entryId, { active = false })
            GRB:Print(L["Broadcast disabled. You can enable it again in the Broadcast tab."])
        end
    end)
    frame.disableEntry:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -GAP / 2, BOTTOM_PADDING)

    frame.disableAll = CreateButton(L["Disable broadcasting"], function()
        GRB.Broadcast:SetActive(false)
    end)
    frame.disableAll:SetPoint("BOTTOMLEFT", frame, "BOTTOM", GAP / 2, BOTTOM_PADDING)

    frame:Hide()
end

-- Shows the oldest ready message, or hides the popup when nothing is ready or broadcasting is paused.
function BroadcastFrame:Update()
    local broadcast = GRB.Broadcast
    local id = broadcast:GetReady()[1]
    local entry = id and broadcast:GetEntry(id)
    local msg = entry and broadcast:GetMessage(entry)
    if not msg or not broadcast:IsActive() or broadcast:GetPauseReason() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Create() end

    frame.entryId = entry.id
    local channel = entry.channel ~= "" and entry.channel or "?"
    frame.text:SetText(format(L["\"%s\" to %s"], msg.name, channel))

    local key = GetBindingKey("GUILDRECRUITMENTBUDDY_SEND")
    local hint = key and format(L["Press %s or click Send."], key) or L["Click Send, or bind a key under Key Bindings."]
    local more = #broadcast:GetReady() - 1
    if more > 0 then
        hint = hint .. " " .. format(L["%d more ready"], more)
    end
    frame.hint:SetText(hint)
    frame:Show()
end
