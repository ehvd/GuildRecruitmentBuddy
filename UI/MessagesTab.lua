local GRB = GuildRecruitmentBuddy
local L = GRB.L

local AceGUI = LibStub("AceGUI-3.0")
local Messages = GRB.Messages

local DELETE_POPUP = "GUILDRECRUITMENTBUDDY_DELETE_MESSAGE"

local ui          -- widgets of the currently shown tab, nil when the tab is not shown
local selectedId  -- id of the message being edited

StaticPopupDialogs[DELETE_POPUP] = {
    text = L["Delete message \"%s\"?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, id)
        Messages:Delete(id)
        if ui then
            ui.RefreshList()
            ui.RefreshEditor()
        end
    end,
}

local function Heading(text)
    local heading = AceGUI:Create("Heading")
    heading:SetText(text)
    heading:SetFullWidth(true)
    return heading
end

local function Label(text)
    local label = AceGUI:Create("Label")
    label:SetText(text or "")
    label:SetFullWidth(true)
    return label
end

local function Build(container)
    container:SetLayout("Fill")
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    container:AddChild(scroll)

    local widgets = {}
    ui = widgets

    -- Selector row ---------------------------------------------------------
    local selector = AceGUI:Create("Dropdown")
    selector:SetLabel(L["Message"])
    selector:SetRelativeWidth(0.44)
    scroll:AddChild(selector)

    local function AddButton(text, onClick)
        local button = AceGUI:Create("Button")
        button:SetText(text)
        button:SetRelativeWidth(0.12)
        button:SetCallback("OnClick", onClick)
        scroll:AddChild(button)
        return button
    end

    widgets.newButton = AddButton(L["New"], function()
        local msg = Messages:Add()
        selectedId = msg.id
        widgets.RefreshList()
        widgets.RefreshEditor()
    end)
    widgets.deleteButton = AddButton(L["Delete"], function()
        local msg = Messages:Get(selectedId)
        if msg then
            StaticPopup_Show(DELETE_POPUP, msg.name, nil, msg.id)
        end
    end)
    widgets.upButton = AddButton(L["Up"], function()
        if selectedId and Messages:Move(selectedId, -1) then widgets.RefreshList() end
    end)
    widgets.downButton = AddButton(L["Down"], function()
        if selectedId and Messages:Move(selectedId, 1) then widgets.RefreshList() end
    end)

    -- Editor ---------------------------------------------------------------
    scroll:AddChild(Heading(L["Edit"]))

    local nameBox = AceGUI:Create("EditBox")
    nameBox:SetLabel(L["Name"])
    nameBox:SetRelativeWidth(0.6)
    nameBox:DisableButton(true)
    scroll:AddChild(nameBox)

    local targetDropdown = AceGUI:Create("Dropdown")
    targetDropdown:SetLabel(L["Send as"])
    targetDropdown:SetList({ whisper = L["Whisper"], channel = L["Channel message"] }, { "whisper", "channel" })
    targetDropdown:SetRelativeWidth(0.4)
    scroll:AddChild(targetDropdown)

    local textBox = AceGUI:Create("MultiLineEditBox")
    textBox:SetLabel(L["Message text"])
    textBox:SetNumLines(6)
    textBox:SetFullWidth(true)
    if textBox.ShowButton then
        textBox:ShowButton(false)
    else
        textBox:DisableButton(true)
    end
    scroll:AddChild(textBox)

    scroll:AddChild(Label(L["Placeholders: {name} {class} {level} {guild} {discord}"]))
    scroll:AddChild(Label(L["Channel, interval and on/off of channel messages are set in the Broadcast tab."]))

    -- Preview --------------------------------------------------------------
    scroll:AddChild(Heading(L["Preview"]))
    local counter = Label()
    scroll:AddChild(counter)
    local warning = Label()
    scroll:AddChild(warning)
    local preview = Label()
    preview:SetFontObject(GameFontHighlight)
    scroll:AddChild(preview)

    -- Behaviour ------------------------------------------------------------
    local function UpdatePreview()
        local msg = Messages:Get(selectedId)
        if not msg then
            counter:SetText("")
            warning:SetText("")
            preview:SetText("")
            scroll:DoLayout()
            return
        end

        -- Channel messages have no recipient, so {name} {class} {level} stay unresolved and are flagged
        local ctx = msg.target == "channel" and Messages:GetBaseContext() or Messages:GetSampleContext()
        local result = Messages:Validate(msg.text, ctx)
        local color = result.ok and "|cff40ff40" or "|cffff4040"
        counter:SetText(format("%s%d / %d|r", color, result.length, Messages.MAX_LENGTH))

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
        warning:SetText(#notes > 0 and ("|cffffd100" .. table.concat(notes, "  ") .. "|r") or "")
        preview:SetText(result.rendered)
        -- Labels start with zero height; re-layout so the rows below move down
        scroll:DoLayout()
    end

    function widgets.RefreshList()
        local values, order = {}, {}
        for _, msg in ipairs(Messages:GetAll()) do
            values[msg.id] = format("%s (%s)", msg.name, msg.target == "channel" and L["Channel"] or L["Whisper"])
            tinsert(order, msg.id)
        end
        selector:SetList(values, order)
        if not Messages:Get(selectedId) then
            selectedId = order[1]
        end
        selector:SetValue(selectedId)
    end

    function widgets.RefreshEditor()
        local msg = Messages:Get(selectedId)
        local disabled = msg == nil
        nameBox:SetDisabled(disabled)
        targetDropdown:SetDisabled(disabled)
        textBox:SetDisabled(disabled)
        widgets.deleteButton:SetDisabled(disabled)
        widgets.upButton:SetDisabled(disabled)
        widgets.downButton:SetDisabled(disabled)

        nameBox:SetText(msg and msg.name or "")
        targetDropdown:SetValue(msg and msg.target or nil)
        textBox:SetText(msg and msg.text or "")
        UpdatePreview()
    end

    selector:SetCallback("OnValueChanged", function(_, _, key)
        selectedId = key
        widgets.RefreshEditor()
    end)
    nameBox:SetCallback("OnTextChanged", function(_, _, value)
        if Messages:Update(selectedId, { name = value }) then widgets.RefreshList() end
    end)
    targetDropdown:SetCallback("OnValueChanged", function(_, _, value)
        if Messages:Update(selectedId, { target = value }) then
            widgets.RefreshList()
            UpdatePreview()
        end
    end)
    textBox:SetCallback("OnTextChanged", function(_, _, value)
        if Messages:Update(selectedId, { text = value }) then UpdatePreview() end
    end)

    widgets.RefreshList()
    widgets.RefreshEditor()
end

local function Cleanup()
    ui = nil
end

GRB.MainFrame:RegisterTab("Messages", L["Messages"], Build, Cleanup)
