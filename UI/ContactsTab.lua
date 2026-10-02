local GRB = GuildRecruitmentBuddy
local L = GRB.L

local AceGUI = LibStub("AceGUI-3.0")
local Contacts = GRB.Contacts

local PAGE_SIZE = 10
local PURGE_POPUP = "GUILDRECRUITMENTBUDDY_PURGE_CONTACTS"
local DELETE_POPUP = "GUILDRECRUITMENTBUDDY_DELETE_CONTACT"

-- State that survives switching tabs while the window is open
local state = {
    page = 1,
    filter = "all",
    sortKey = "timestamp",
    sortAscending = false,
    purgeDays = 30,
    whisperName = "",
    templateId = nil,
}

local ui   -- refresh callbacks of the visible tab, nil when the tab is not shown

StaticPopupDialogs[PURGE_POPUP] = {
    text = L["Delete all contacts last contacted more than %d days ago? (\"Do not contact\" entries are kept.)"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, days)
        local removed = Contacts:Purge(days)
        GRB:Printf(L["Purged %d contact(s)."], removed)
        if ui then ui.RefreshList() end
    end,
}

StaticPopupDialogs[DELETE_POPUP] = {
    text = L["Delete contact \"%s\"?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, key)
        Contacts:Delete(key)
        if ui then ui.RefreshList() end
    end,
}

local function Heading(text)
    local heading = AceGUI:Create("Heading")
    heading:SetText(text)
    heading:SetFullWidth(true)
    return heading
end

local function StatusList()
    local values = {}
    for _, status in ipairs(Contacts.STATUSES) do
        values[status] = Contacts.STATUS_LABELS[status]
    end
    return values
end

local COLUMNS = {
    { key = "name", label = L["Name"], width = 0.22 },
    { key = "class", label = L["Class"], width = 0.14 },
    { key = "level", label = L["Level"], width = 0.08 },
    { key = "status", label = L["Status"], width = 0.24 },
    { key = "timestamp", label = L["Last contacted"], width = 0.18 },
}

local function Build(container)
    container:SetLayout("Fill")
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    container:AddChild(scroll)

    local widgets = {}
    ui = widgets

    -- Toolbar: filter + purge -----------------------------------------------
    scroll:AddChild(Heading(L["Contacts"]))

    local filterValues = StatusList()
    filterValues.all = L["All"]
    local filterOrder = { "all" }
    for _, status in ipairs(Contacts.STATUSES) do tinsert(filterOrder, status) end

    local filter = AceGUI:Create("Dropdown")
    filter:SetLabel(L["Filter by status"])
    filter:SetList(filterValues, filterOrder)
    filter:SetValue(state.filter)
    filter:SetRelativeWidth(0.34)
    scroll:AddChild(filter)

    local purgeBox = AceGUI:Create("EditBox")
    purgeBox:SetLabel(L["Purge older than (days)"])
    purgeBox:SetText(tostring(state.purgeDays))
    purgeBox:SetRelativeWidth(0.3)
    purgeBox:DisableButton(true)
    scroll:AddChild(purgeBox)

    local purgeButton = AceGUI:Create("Button")
    purgeButton:SetText(L["Purge"])
    purgeButton:SetRelativeWidth(0.2)
    scroll:AddChild(purgeButton)

    -- Table ------------------------------------------------------------------
    local header = AceGUI:Create("SimpleGroup")
    header:SetLayout("Flow")
    header:SetFullWidth(true)
    scroll:AddChild(header)

    local list = AceGUI:Create("SimpleGroup")
    list:SetLayout("Flow")
    list:SetFullWidth(true)
    scroll:AddChild(list)

    local prevButton = AceGUI:Create("Button")
    prevButton:SetText("<")
    prevButton:SetRelativeWidth(0.15)
    scroll:AddChild(prevButton)

    local pageLabel = AceGUI:Create("Label")
    pageLabel:SetRelativeWidth(0.6)
    scroll:AddChild(pageLabel)

    local nextButton = AceGUI:Create("Button")
    nextButton:SetText(">")
    nextButton:SetRelativeWidth(0.15)
    scroll:AddChild(nextButton)

    -- Manual whisper -------------------------------------------------------------
    scroll:AddChild(Heading(L["Whisper a player"]))

    local nameBox = AceGUI:Create("EditBox")
    nameBox:SetLabel(L["Player name"])
    nameBox:SetText(state.whisperName)
    nameBox:SetRelativeWidth(0.35)
    nameBox:DisableButton(true)
    scroll:AddChild(nameBox)

    local templateDropdown = AceGUI:Create("Dropdown")
    templateDropdown:SetLabel(L["Message"])
    templateDropdown:SetRelativeWidth(0.4)
    scroll:AddChild(templateDropdown)

    local sendButton = AceGUI:Create("Button")
    sendButton:SetText(L["Send"])
    sendButton:SetRelativeWidth(0.2)
    scroll:AddChild(sendButton)

    local reason = AceGUI:Create("Label")
    reason:SetFullWidth(true)
    scroll:AddChild(reason)

    -- Behaviour --------------------------------------------------------------
    local statusValues = StatusList()

    local function RefreshHeader()
        header:ReleaseChildren()
        for _, column in ipairs(COLUMNS) do
            local label = AceGUI:Create("InteractiveLabel")
            local arrow = ""
            if state.sortKey == column.key then
                arrow = state.sortAscending and " ^" or " v"
            end
            label:SetText("|cffffd100" .. column.label .. arrow .. "|r")
            label:SetRelativeWidth(column.width)
            label:SetCallback("OnClick", function()
                if state.sortKey == column.key then
                    state.sortAscending = not state.sortAscending
                else
                    state.sortKey = column.key
                    state.sortAscending = column.key == "name" or column.key == "class"
                end
                state.page = 1
                widgets.RefreshList()
            end)
            header:AddChild(label)
        end
    end

    local function AddRow(entry)
        local contact = entry.contact
        local function Text(text, width)
            local label = AceGUI:Create("Label")
            label:SetText(text)
            label:SetRelativeWidth(width)
            list:AddChild(label)
        end

        Text(contact.name or entry.key, COLUMNS[1].width)
        Text(contact.class or "-", COLUMNS[2].width)
        Text(contact.level and tostring(contact.level) or "-", COLUMNS[3].width)

        local statusDropdown = AceGUI:Create("Dropdown")
        statusDropdown:SetLabel("")
        statusDropdown:SetList(statusValues, Contacts.STATUSES)
        statusDropdown:SetValue(contact.status)
        statusDropdown:SetRelativeWidth(COLUMNS[4].width)
        statusDropdown:SetCallback("OnValueChanged", function(_, _, value)
            Contacts:SetStatus(entry.key, value)
            if state.filter ~= "all" then widgets.RefreshList() end
        end)
        list:AddChild(statusDropdown)

        Text(contact.timestamp and date("%Y-%m-%d", contact.timestamp) or "-", COLUMNS[5].width)

        local delete = AceGUI:Create("Button")
        delete:SetText(L["Delete"])
        delete:SetRelativeWidth(0.12)
        delete:SetCallback("OnClick", function()
            StaticPopup_Show(DELETE_POPUP, entry.key, nil, entry.key)
        end)
        list:AddChild(delete)
    end

    function widgets.RefreshList()
        local entries = Contacts:GetList(state.filter, state.sortKey, state.sortAscending)
        local pages = max(1, ceil(#entries / PAGE_SIZE))
        state.page = min(max(state.page, 1), pages)

        RefreshHeader()
        list:ReleaseChildren()
        local first = (state.page - 1) * PAGE_SIZE + 1
        for i = first, min(first + PAGE_SIZE - 1, #entries) do
            AddRow(entries[i])
        end

        pageLabel:SetText(format(L["Page %d / %d (%d contacts)"], state.page, pages, #entries))
        prevButton:SetDisabled(state.page <= 1)
        nextButton:SetDisabled(state.page >= pages)
        scroll:DoLayout()
    end

    function widgets.RefreshWhisper()
        local ok, why = GRB.Whisper:CanSend(state.whisperName, state.templateId)
        sendButton:SetDisabled(not ok)
        reason:SetText(ok and "" or ("|cffff6060" .. why .. "|r"))
        scroll:DoLayout()
    end

    local function RefreshTemplates()
        local values, order = {}, {}
        for _, msg in ipairs(GRB.Messages:GetAll()) do
            if msg.target == "whisper" then
                values[msg.id] = msg.name
                tinsert(order, msg.id)
            end
        end
        templateDropdown:SetList(values, order)
        if not values[state.templateId] then
            state.templateId = order[1]
        end
        templateDropdown:SetValue(state.templateId)
    end

    filter:SetCallback("OnValueChanged", function(_, _, value)
        state.filter = value
        state.page = 1
        widgets.RefreshList()
    end)
    purgeBox:SetCallback("OnTextChanged", function(_, _, value)
        state.purgeDays = tonumber(value) or state.purgeDays
    end)
    purgeButton:SetCallback("OnClick", function()
        if state.purgeDays > 0 then
            StaticPopup_Show(PURGE_POPUP, state.purgeDays, nil, state.purgeDays)
        end
    end)
    prevButton:SetCallback("OnClick", function()
        state.page = state.page - 1
        widgets.RefreshList()
    end)
    nextButton:SetCallback("OnClick", function()
        state.page = state.page + 1
        widgets.RefreshList()
    end)
    nameBox:SetCallback("OnTextChanged", function(_, _, value)
        state.whisperName = value
        widgets.RefreshWhisper()
    end)
    templateDropdown:SetCallback("OnValueChanged", function(_, _, value)
        state.templateId = value
        widgets.RefreshWhisper()
    end)
    sendButton:SetCallback("OnClick", function()
        local ok, why = GRB.Whisper:Send(state.whisperName, state.templateId)
        if ok then
            GRB:Printf(L["Whisper sent to %s."], state.whisperName)
            nameBox:SetText("")
            state.whisperName = ""
            widgets.RefreshList()
        else
            GRB:Print(why)
        end
        widgets.RefreshWhisper()
    end)

    RefreshTemplates()
    widgets.RefreshList()
    widgets.RefreshWhisper()
end

local function Cleanup()
    ui = nil
end

GRB.MainFrame:RegisterTab("Contacts", L["Contacts"], Build, Cleanup)
