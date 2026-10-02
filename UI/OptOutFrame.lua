local GRB = GuildRecruitmentBuddy
local L = GRB.L

-- Small movable popup that asks what to do with a player who seems to have opted out of recruitment whispers:
-- it shows the message that triggered the request, with buttons to put the player on the do-not-contact list
-- ("Opt out") or to skip the request (the player then stays a normal contact).
local OptOutFrame = {}
GRB.OptOutFrame = OptOutFrame

local frame

local WIDTH = 330
local TEXT_WIDTH = 290
local BUTTON_WIDTH = 140
local BUTTON_HEIGHT = 24
local GAP = 10
local TOP_PADDING = 24
local BOTTOM_PADDING = 22

local function CreateButton(text, onClick)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Create()
    frame = CreateFrame("Frame", "GuildRecruitmentBuddyOptOutFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 120)
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
    frame.title:SetPoint("TOP", frame, "TOP", 0, -TOP_PADDING)
    frame.title:SetText(L["Opt-out request"])

    frame.who = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.who:SetPoint("TOP", frame.title, "BOTTOM", 0, -10)
    frame.who:SetWidth(TEXT_WIDTH)

    -- The message that triggered the request
    frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.message:SetPoint("TOP", frame.who, "BOTTOM", 0, -6)
    frame.message:SetWidth(TEXT_WIDTH)
    frame.message:SetJustifyH("CENTER")
    frame.message:SetWordWrap(true)
    frame.message:SetTextColor(1, 1, 1)

    frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.more:SetPoint("TOP", frame.message, "BOTTOM", 0, -6)
    frame.more:SetWidth(TEXT_WIDTH)

    frame.confirm = CreateButton(L["Opt out"], function()
        GRB.OptOut:ConfirmNext()
    end)
    frame.confirm:SetPoint("BOTTOMLEFT", frame, "BOTTOM", GAP / 2, BOTTOM_PADDING)

    frame.skip = CreateButton(L["Skip"], function()
        GRB.OptOut:SkipNext()
    end)
    frame.skip:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -GAP / 2, BOTTOM_PADDING)

    frame:Hide()
end

-- The frame is exactly as tall as its content, so there is no empty space whatever the message length
local function Resize()
    local height = TOP_PADDING + frame.title:GetStringHeight() + 10 + frame.who:GetStringHeight()
        + 6 + frame.message:GetStringHeight()
    if frame.more:GetText() ~= "" then
        height = height + 6 + frame.more:GetStringHeight()
    end
    frame:SetHeight(height + 14 + BUTTON_HEIGHT + BOTTOM_PADDING)
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
    Resize()
    frame:Show()
    -- Text heights are only exact once the frame has been laid out, so measure again on the next frame
    C_Timer.After(0, function()
        if frame:IsShown() then Resize() end
    end)
end
