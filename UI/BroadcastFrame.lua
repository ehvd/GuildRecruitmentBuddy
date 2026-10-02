local GRB = GuildRecruitmentBuddy
local L = GRB.L

-- Small movable popup shown while a channel broadcast is ready. Clicking Send (or pressing the keybind /
-- using `/grb send`) is the hardware event that SendChatMessage to a channel requires.
local BroadcastFrame = {}
GRB.BroadcastFrame = BroadcastFrame

local frame

local function Create()
    frame = CreateFrame("Frame", "GuildRecruitmentBuddyBroadcastFrame", UIParent, "BackdropTemplate")
    frame:SetSize(300, 120)
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
    frame.title:SetPoint("TOP", frame, "TOP", 0, -18)
    frame.title:SetText(L["Broadcast ready"])

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
    frame.text:SetWidth(270)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.hint:SetPoint("TOP", frame.text, "BOTTOM", 0, -4)
    frame.hint:SetWidth(270)

    frame.send = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.send:SetSize(110, 24)
    frame.send:SetPoint("BOTTOMLEFT", frame, "BOTTOM", -115, 18)
    frame.send:SetText(L["Send"])
    frame.send:SetScript("OnClick", function()
        GRB.Broadcast:SendNext()
    end)

    frame.skip = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.skip:SetSize(110, 24)
    frame.skip:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 115, 18)
    frame.skip:SetText(L["Skip"])
    frame.skip:SetScript("OnClick", function()
        GRB.Broadcast:SkipNext()
    end)

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
