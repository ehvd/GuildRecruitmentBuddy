local GRB = GuildRecruitmentBuddy
local L = GRB.L

-- Small movable popup that asks what to do with a player who seems to have opted out of recruitment whispers:
-- it shows the message that triggered the request, with buttons to put the player on the do-not-contact list
-- or to skip the request (the player then stays a normal contact).
local OptOutFrame = {}
GRB.OptOutFrame = OptOutFrame

local frame

local BUTTON_WIDTH = 150
local BUTTON_HEIGHT = 24
local GAP = 10
local BOTTOM_PADDING = 28

local function CreateButton(text, onClick)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Create()
    frame = CreateFrame("Frame", "GuildRecruitmentBuddyOptOutFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 210)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -480)
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
    frame.title:SetText(L["Opt-out request"])

    frame.who = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.who:SetPoint("TOP", frame.title, "BOTTOM", 0, -12)
    frame.who:SetWidth(310)

    -- The message that triggered the request
    frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.message:SetPoint("TOP", frame.who, "BOTTOM", 0, -8)
    frame.message:SetWidth(310)
    frame.message:SetJustifyH("CENTER")
    frame.message:SetWordWrap(true)
    frame.message:SetTextColor(1, 1, 1)

    frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.more:SetPoint("BOTTOM", frame, "BOTTOM", 0, BOTTOM_PADDING + BUTTON_HEIGHT + 8)
    frame.more:SetWidth(310)

    frame.confirm = CreateButton(L["Add to do-not-contact list"], function()
        GRB.OptOut:ConfirmNext()
    end)
    frame.confirm:SetSize(BUTTON_WIDTH + 30, BUTTON_HEIGHT)
    frame.confirm:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -GAP / 2, BOTTOM_PADDING)

    frame.skip = CreateButton(L["Skip"], function()
        GRB.OptOut:SkipNext()
    end)
    frame.skip:SetSize(BUTTON_WIDTH - 30, BUTTON_HEIGHT)
    frame.skip:SetPoint("BOTTOMLEFT", frame, "BOTTOM", GAP / 2, BOTTOM_PADDING)

    frame:Hide()
end

-- Shows the first pending request, or hides the popup when there is none or quiet mode is active.
function OptOutFrame:Update()
    local queue = GRB.OptOut:GetQueue()
    local entry = queue[1]
    if not entry or GRB.Quiet:IsQuiet() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Create() end

    frame.who:SetText(format(L["%s replied:"], entry.name))
    -- "|" starts escape sequences in chat text, so a player's message must not be able to inject any
    frame.message:SetText("\"" .. gsub(entry.text, "|", "||") .. "\"")
    frame.more:SetText(#queue > 1 and format(L["%d more waiting"], #queue - 1) or "")
    frame:Show()
end
