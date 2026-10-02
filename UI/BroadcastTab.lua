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

-- One line describing whether and when an entry is sent
local function StatusLine(entry)
    local state, extra = Broadcast:GetState(entry.id)
    if state == "invalid" then
        return "|cffff6060" .. L["The message was deleted or is no longer a channel message."] .. "|r"
    elseif state == "inactive" then
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
    if not Broadcast:FindChannel(entry.channel) then
        text = text .. "  |cffff6060" .. L["(channel not joined)"] .. "|r"
    end
    return color .. text .. "|r"
end

-- The text of the entry's message as it is sent to the channel, with a note for placeholders that stay unfilled
local function PreviewText(entry)
    local msg = Broadcast:GetMessage(entry)
    if not msg then return "" end
    local result = Messages:Validate(msg.text, Messages:GetBaseContext())
    local text = result.rendered
    local notes = {}
    if result.length > Messages.MAX_LENGTH then
        tinsert(notes, format(L["Too long by %d characters."], result.length - Messages.MAX_LENGTH))
    end
    if #result.unknown > 0 then
        tinsert(notes, format(L["Unknown placeholders: %s"], table.concat(result.unknown, " ")))
    end
    if #result.unresolved > 0 then
        tinsert(notes, format(L["Not set (see Settings): %s"], table.concat(result.unresolved, " ")))
    end
    if #notes > 0 then
        text = text .. "\n|cffffd100" .. table.concat(notes, "  ") .. "|r"
    end
    return text
end

local function ChannelMessages()
    local list = {}
    for _, msg in ipairs(Messages:GetAll()) do
        if msg.target == "channel" then tinsert(list, msg) end
    end
    return list
end

-- Lists the channels joined right now; a saved channel that is not joined stays selectable.
local function FillChannels(dropdown, entry)
    local values, order = {}, {}
    local current = entry.channel or ""
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

local function FillMessages(dropdown, entry)
    local values, order = {}, {}
    for _, msg in ipairs(ChannelMessages()) do
        values[msg.id] = msg.name
        tinsert(order, msg.id)
    end
    dropdown:SetList(values, order)
    dropdown:SetValue(values[entry.messageId] and entry.messageId or nil)
end

-- Rebuilds the whole tab (after an entry was added, removed or got another message)
-- Deferred by a frame so the widget whose callback triggered it is not released while it is still running.
local function Rebuild()
    C_Timer.After(0, function()
        if GRB.MainFrame.currentTab == "Broadcast" then
            GRB.MainFrame:SelectTab("Broadcast")
        end
    end)
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
    masterBox:SetRelativeWidth(0.68)
    masterBox:SetCallback("OnValueChanged", function(_, _, value)
        Broadcast:SetActive(value)
    end)
    scroll:AddChild(masterBox)

    local addButton = AceGUI:Create("Button")
    addButton:SetText(L["Add broadcast"])
    addButton:SetRelativeWidth(0.3)
    addButton:SetCallback("OnClick", function()
        local messages = ChannelMessages()
        if #messages == 0 then
            GRB:Print(L["Create a channel message in the Messages tab first (Send as: Channel message)."])
            return
        end
        Broadcast:AddEntry(messages[1].id)
        Rebuild()
    end)
    scroll:AddChild(addButton)

    local intro = AceGUI:Create("Label")
    intro:SetText(L["Each broadcast sends one channel message to one channel. Add several to use a message in more channels."])
    intro:SetFullWidth(true)
    scroll:AddChild(intro)

    local list = AceGUI:Create("SimpleGroup")
    list:SetLayout("Flow")
    list:SetFullWidth(true)
    scroll:AddChild(list)

    local statusLabels = {}   -- entry id -> status label refreshed by the ticker
    local count = 0

    for index, entry in ipairs(Broadcast:GetEntries()) do
        count = count + 1
        local id = entry.id

        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(format(L["Broadcast %d"], index))
        group:SetLayout("Flow")
        group:SetFullWidth(true)

        -- Row 1: what is sent, where and how often
        local messageDropdown = AceGUI:Create("Dropdown")
        messageDropdown:SetLabel(L["Message"])
        messageDropdown:SetRelativeWidth(0.33)
        FillMessages(messageDropdown, entry)
        group:AddChild(messageDropdown)

        local channel = AceGUI:Create("Dropdown")
        channel:SetLabel(L["Channel"])
        channel:SetRelativeWidth(0.33)
        FillChannels(channel, entry)
        group:AddChild(channel)

        local interval = AceGUI:Create("Slider")
        interval:SetLabel(L["Every (minutes)"])
        interval:SetSliderValues(1, Broadcast.MAX_INTERVAL, 1)
        interval:SetValue(entry.interval)
        interval:SetRelativeWidth(0.3)
        group:AddChild(interval)

        -- Preview of the message that is sent
        local preview = AceGUI:Create("Label")
        preview:SetFontObject(GameFontHighlight)
        preview:SetText(PreviewText(entry))
        preview:SetFullWidth(true)
        group:AddChild(preview)

        -- Row 2: state and actions
        local active = AceGUI:Create("CheckBox")
        active:SetLabel(L["Active"])
        active:SetValue(entry.active)
        active:SetRelativeWidth(0.18)
        group:AddChild(active)

        local status = AceGUI:Create("Label")
        status:SetText(StatusLine(entry))
        status:SetRelativeWidth(0.44)
        group:AddChild(status)
        statusLabels[id] = status

        local send = AceGUI:Create("Button")
        send:SetText(L["Send now"])
        send:SetRelativeWidth(0.18)
        group:AddChild(send)

        local remove = AceGUI:Create("Button")
        remove:SetText(L["Remove"])
        remove:SetRelativeWidth(0.18)
        group:AddChild(remove)
        local function Refresh()
            local current = Broadcast:GetEntry(id)
            if current then status:SetText(StatusLine(current)) end
        end

        messageDropdown:SetCallback("OnValueChanged", function(_, _, value)
            Broadcast:UpdateEntry(id, { messageId = value })
            Rebuild()
        end)
        channel:SetCallback("OnValueChanged", function(_, _, value)
            Broadcast:UpdateEntry(id, { channel = value })
            Refresh()
        end)
        interval:SetCallback("OnValueChanged", function(_, _, value)
            Broadcast:UpdateEntry(id, { interval = value })
            Refresh()
        end)
        active:SetCallback("OnValueChanged", function(_, _, value)
            Broadcast:UpdateEntry(id, { active = value })
            Refresh()
        end)
        remove:SetCallback("OnClick", function()
            Broadcast:DeleteEntry(id)
            Rebuild()
        end)
        send:SetCallback("OnClick", function()
            Broadcast:SendEntry(id)
            Refresh()
        end)

        list:AddChild(group)
    end

    if count == 0 then
        local empty = AceGUI:Create("Label")
        empty:SetText(L["No broadcasts yet. Write a channel message in the Messages tab, then click Add broadcast."])
        empty:SetFullWidth(true)
        list:AddChild(empty)
    end
    scroll:DoLayout()

    ticker = GRB:ScheduleRepeatingTimer(function()
        masterBox:SetValue(Broadcast:IsActive())
        for id, label in pairs(statusLabels) do
            local entry = Broadcast:GetEntry(id)
            if entry then label:SetText(StatusLine(entry)) end
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
