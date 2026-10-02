local GRB = GuildRecruitmentBuddy
local L = GRB.L

local AceGUI = LibStub("AceGUI-3.0")
local Broadcast = GRB.Broadcast
local Messages = GRB.Messages

local ticker   -- repeating timer that keeps states and countdowns current

local COLUMNS = {
    { label = L["Name"], width = 0.22 },
    { label = L["Channel"], width = 0.15 },
    { label = L["Every"], width = 0.09 },
    { label = L["State"], width = 0.24 },
    { label = L["Next send"], width = 0.1 },
}
local BUTTON_WIDTH = 0.18

local function FormatTime(seconds)
    seconds = max(0, ceil(seconds))
    return format("%d:%02d", floor(seconds / 60), seconds % 60)
end

-- Returns the state text and the countdown text of a channel message
local function Describe(id)
    local state, extra = Broadcast:GetState(id)
    if state == "inactive" then
        return "|cff999999" .. L["Inactive"] .. "|r", "-"
    elseif state == "off" then
        return "|cffffd100" .. L["Switched off"] .. "|r", "-"
    elseif state == "paused" then
        return "|cffffd100" .. format(L["Paused (%s)"], extra) .. "|r", "-"
    elseif state == "ready" then
        return "|cff40ff40" .. L["Active"] .. "|r", "|cff40ff40" .. L["Ready"] .. "|r"
    end
    return "|cff40ff40" .. L["Active"] .. "|r", FormatTime(extra)
end

local function ChannelText(msg)
    if msg.channel == "" then return "|cffff6060?|r" end
    if not Broadcast:FindChannel(msg.channel) then
        return "|cffff6060" .. msg.channel .. "|r"
    end
    return msg.channel
end

local function Build(container)
    container:SetLayout("Fill")
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    container:AddChild(scroll)

    local heading = AceGUI:Create("Heading")
    heading:SetText(L["Channel broadcasts"])
    heading:SetFullWidth(true)
    scroll:AddChild(heading)

    local masterBox = AceGUI:Create("CheckBox")
    masterBox:SetLabel(L["Interval broadcasting enabled"])
    masterBox:SetValue(Broadcast:IsActive())
    masterBox:SetFullWidth(true)
    masterBox:SetCallback("OnValueChanged", function(_, _, value)
        Broadcast:SetActive(value)
    end)
    scroll:AddChild(masterBox)

    local intro = AceGUI:Create("Label")
    intro:SetText(L["Channel messages are set up in the Messages tab. Send now sends immediately and restarts the timer."])
    intro:SetFullWidth(true)
    scroll:AddChild(intro)

    local header = AceGUI:Create("SimpleGroup")
    header:SetLayout("Flow")
    header:SetFullWidth(true)
    scroll:AddChild(header)
    for _, column in ipairs(COLUMNS) do
        local label = AceGUI:Create("Label")
        label:SetText("|cffffd100" .. column.label .. "|r")
        label:SetRelativeWidth(column.width)
        header:AddChild(label)
    end

    local list = AceGUI:Create("SimpleGroup")
    list:SetLayout("Flow")
    list:SetFullWidth(true)
    scroll:AddChild(list)

    local rows = {}   -- message id -> { msg, channel, state, time } labels updated by the ticker
    local count = 0

    local function AddText(width)
        local label = AceGUI:Create("Label")
        label:SetRelativeWidth(width)
        list:AddChild(label)
        return label
    end

    local function RefreshRow(row)
        local state, time = Describe(row.msg.id)
        row.channel:SetText(ChannelText(row.msg))
        row.state:SetText(state)
        row.time:SetText(time)
    end

    for _, msg in ipairs(Messages:GetAll()) do
        if msg.target == "channel" then
            count = count + 1
            local row = { msg = msg }
            rows[msg.id] = row

            local name = AddText(COLUMNS[1].width)
            name:SetText(msg.name)
            row.channel = AddText(COLUMNS[2].width)
            local every = AddText(COLUMNS[3].width)
            every:SetText(format(L["%d min"], msg.interval or Messages.DEFAULT_INTERVAL))
            row.state = AddText(COLUMNS[4].width)
            row.time = AddText(COLUMNS[5].width)

            local send = AceGUI:Create("Button")
            send:SetText(L["Send now"])
            send:SetRelativeWidth(BUTTON_WIDTH)
            send:SetCallback("OnClick", function()
                Broadcast:SendMessage(msg.id)
                RefreshRow(row)
            end)
            list:AddChild(send)

            RefreshRow(row)
        end
    end

    if count == 0 then
        local empty = AceGUI:Create("Label")
        empty:SetText(L["No channel messages yet. Create one in the Messages tab (Send as: Channel message)."])
        empty:SetFullWidth(true)
        list:AddChild(empty)
    end
    scroll:DoLayout()

    ticker = GRB:ScheduleRepeatingTimer(function()
        masterBox:SetValue(Broadcast:IsActive())
        for _, row in pairs(rows) do
            RefreshRow(row)
        end
    end, 1)
end

local function Cleanup()
    if ticker then
        GRB:CancelTimer(ticker)
        ticker = nil
    end
end

GRB.MainFrame:RegisterTab("Broadcast", L["Broadcast"], Build, Cleanup)
