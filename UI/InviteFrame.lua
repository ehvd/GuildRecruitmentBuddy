local GRB = GuildRecruitmentBuddy
local L = GRB.L

-- Small movable popup that turns queued "ginv" requests into one click each.
-- The click is the hardware event that C_GuildInfo.Invite requires.
local InviteFrame = {}
GRB.InviteFrame = InviteFrame

local frame

local function Create()
    frame = CreateFrame("Frame", "GuildRecruitmentBuddyInviteFrame", UIParent, "BackdropTemplate")
    frame:SetSize(300, 110)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -160)
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
    frame.title:SetText(L["Guild invite request"])

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
    frame.text:SetWidth(270)

    frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.more:SetPoint("TOP", frame.text, "BOTTOM", 0, -4)

    frame.invite = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.invite:SetSize(110, 24)
    frame.invite:SetPoint("BOTTOMLEFT", frame, "BOTTOM", -115, 18)
    frame.invite:SetText(L["Invite"])
    frame.invite:SetScript("OnClick", function()
        GRB.AutoInvite:AcceptNext()
    end)

    frame.skip = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.skip:SetSize(110, 24)
    frame.skip:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 115, 18)
    frame.skip:SetText(L["Skip"])
    frame.skip:SetScript("OnClick", function()
        GRB.AutoInvite:SkipNext()
    end)

    frame:Hide()
end

-- Shows the first queued request, or hides the popup when the queue is empty or quiet mode is active.
function InviteFrame:Update()
    local queue = GRB.AutoInvite:GetQueue()
    local entry = queue[1]
    if not entry or GRB.Quiet:IsQuiet() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Create() end

    frame.text:SetText(format(L["Invite %s (%s, level %s)?"], entry.target, entry.class or "?", entry.level or "?"))
    frame.more:SetText(#queue > 1 and format(L["%d more waiting"], #queue - 1) or "")
    frame:Show()
end
