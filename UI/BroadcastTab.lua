local GRB = GuildRecruitmentBuddy
local L = GRB.L

local AceGUI = LibStub("AceGUI-3.0")
local Broadcast = GRB.Broadcast
local Messages = GRB.Messages

local ticker   -- repeating timer that keeps states and countdowns current

local function FormatTime(seconds)
    seconds = max(0, ceil(seconds))
    return format("%d:%02d", floor(seconds / 60), seconds % 60)
end

-- One line describing whether and when a channel message is sent
local function StatusLine(msg)
    local state, extra = Broadcast:GetState(msg.id)
    if state == "inactive" then
        return "|cff999999" .. L["Inactive"] .. "|r"
    end

    local text, color
    if state == "off" then
        text, color = L["Active - broadcasting is switched off"], "|cffffd100"
    elseif state == "paused" then
        text, color = format(L["Active - paused (%s)"], extra), "|cffffd100"
    elseif state == "ready" then
        text, color = L["Active - ready to send"], "|cff40ff40"
    else
        text, color = format(L["Active - next send in %s"], FormatTime(extra)), "|cff40ff40"
    end
    if not Broadcast:FindChannel(msg.channel) then
        text = text .. "  |cffff6060" .. L["(channel not joined)"] .. "|r"
    end
    return color .. text .. "|r"
end

-- Lists the channels joined right now; a saved channel that is not joined stays selectable.
local function FillChannels(dropdown, msg)
    local values, order = {}, {}
    local current = msg.channel or ""
    local selected
    for _, name in ipairs(Broadcast:GetJoinedChannels()) do
        values[name] = name
        tinsert(order, name)
        if name:lower() == current:lower() then selected = name end
    end
    if current ~= "" and not selected then
        values[current] = format(L["%s (not joined)"], current)
        tinsert(order, current)
        selected = current
    end
    dropdown:SetList(values, order)
    dropdown:SetValue(selected)
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
    intro:SetText(L["Write channel messages in the Messages tab. Send now sends at once and restarts the timer."])
    intro:SetFullWidth(true)
    scroll:AddChild(intro)

    local list = AceGUI:Create("SimpleGroup")
    list:SetLayout("Flow")
    list:SetFullWidth(true)
    scroll:AddChild(list)

    local statusLabels = {}   -- message id -> status label refreshed by the ticker
    local count = 0

    for _, msg in ipairs(Messages:GetAll()) do
        if msg.target == "channel" then
            count = count + 1

            local group = AceGUI:Create("InlineGroup")
            group:SetTitle(msg.name)
            group:SetLayout("Flow")
            group:SetFullWidth(true)

            local channel = AceGUI:Create("Dropdown")
            channel:SetLabel(L["Channel"])
            channel:SetRelativeWidth(0.34)
            FillChannels(channel, msg)
            group:AddChild(channel)

            local interval = AceGUI:Create("Slider")
            interval:SetLabel(L["Every (minutes)"])
            interval:SetSliderValues(1, Messages.MAX_INTERVAL, 1)
            interval:SetValue(msg.interval or Messages.DEFAULT_INTERVAL)
            interval:SetRelativeWidth(0.38)
            group:AddChild(interval)

            local active = AceGUI:Create("CheckBox")
            active:SetLabel(L["Active"])
            active:SetValue(msg.broadcast == true)
            active:SetRelativeWidth(0.26)
            group:AddChild(active)

            local status = AceGUI:Create("Label")
            status:SetText(StatusLine(msg))
            status:SetRelativeWidth(0.7)
            group:AddChild(status)
            statusLabels[msg.id] = status

            local send = AceGUI:Create("Button")
            send:SetText(L["Send now"])
            send:SetRelativeWidth(0.28)
            group:AddChild(send)

            local function Refresh()
                status:SetText(StatusLine(Messages:Get(msg.id) or msg))
            end

            channel:SetCallback("OnValueChanged", function(_, _, value)
                Messages:Update(msg.id, { channel = value })
                Refresh()
            end)
            interval:SetCallback("OnValueChanged", function(_, _, value)
                Messages:Update(msg.id, { interval = value })
                Refresh()
            end)
            active:SetCallback("OnValueChanged", function(_, _, value)
                Messages:Update(msg.id, { broadcast = value })
                Refresh()
            end)
            send:SetCallback("OnClick", function()
                Broadcast:SendMessage(msg.id)
                Refresh()
            end)

            list:AddChild(group)
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
        for id, label in pairs(statusLabels) do
            local msg = Messages:Get(id)
            if msg then label:SetText(StatusLine(msg)) end
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
