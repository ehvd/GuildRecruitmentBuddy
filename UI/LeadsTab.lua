local GRB = GuildRecruitmentBuddy
local L = GRB.L

local AceGUI = LibStub("AceGUI-3.0")
local Contacts = GRB.Contacts

local PAGE_SIZE = 6

local state = {
    page = 1,
    templateId = nil,
}

local function Heading(text)
    local heading = AceGUI:Create("Heading")
    heading:SetText(text)
    heading:SetFullWidth(true)
    return heading
end

local function Build(container)
    container:SetLayout("Fill")
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    container:AddChild(scroll)

    local widgets = {}

    scroll:AddChild(Heading(L["Leads"]))

    local intro = AceGUI:Create("Label")
    intro:SetText(L["Players who replied with interest. Their replies are kept here, and leads are never pruned or purged."])
    intro:SetFullWidth(true)
    scroll:AddChild(intro)

    local templateDropdown = AceGUI:Create("Dropdown")
    templateDropdown:SetLabel(L["Follow-up message"])
    templateDropdown:SetRelativeWidth(0.5)
    scroll:AddChild(templateDropdown)

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

    local function AddRow(entry)
        local contact = entry.contact
        local reply = Contacts:GetLastReply(contact)
        local ok, reason = Contacts:CanContact(entry.key)

        local lines = {
            format("|cffffd100%s|r  %s %s", contact.name or entry.key, contact.class or "", contact.level and ("L" .. contact.level) or ""),
        }
        if reply then
            -- "|" starts escape sequences in chat text, so a player's message must not be able to inject any
            tinsert(lines, format("|cff999999%s|r", date("%Y-%m-%d %H:%M", reply.t)))
            tinsert(lines, "\"" .. gsub(reply.text, "|", "||") .. "\"")
        else
            tinsert(lines, "|cff999999" .. L["(no saved reply)"] .. "|r")
        end
        if not ok then
            tinsert(lines, "|cffff6060" .. reason .. "|r")
        end

        local info = AceGUI:Create("Label")
        info:SetText(table.concat(lines, "\n"))
        info:SetRelativeWidth(0.55)
        list:AddChild(info)

        local whisper = AceGUI:Create("Button")
        whisper:SetText(L["Whisper"])
        whisper:SetRelativeWidth(0.15)
        whisper:SetDisabled(not ok or not state.templateId)
        whisper:SetCallback("OnClick", function()
            local sent, why = GRB.Whisper:Send(entry.key, state.templateId, { class = contact.class, level = contact.level })
            if not sent and why then GRB:Print(why) end
            widgets.Refresh()
        end)
        list:AddChild(whisper)

        local invite = AceGUI:Create("Button")
        invite:SetText(L["Invite"])
        invite:SetRelativeWidth(0.14)
        invite:SetCallback("OnClick", function()
            GRB.AutoInvite:InviteNow({
                key = entry.key,
                target = Contacts:GetWhisperTarget(entry.key),
                class = contact.class,
                level = contact.level,
            }, false)
            widgets.Refresh()
        end)
        list:AddChild(invite)

        local remove = AceGUI:Create("Button")
        remove:SetText(L["Remove"])
        remove:SetRelativeWidth(0.14)
        remove:SetCallback("OnClick", function()
            Contacts:RemoveLead(entry.key)
            widgets.Refresh()
        end)
        list:AddChild(remove)
    end

    function widgets.Refresh()
        local leads = Contacts:GetLeads()
        local pages = max(1, ceil(#leads / PAGE_SIZE))
        state.page = min(max(state.page, 1), pages)

        list:ReleaseChildren()
        if #leads == 0 then
            local empty = AceGUI:Create("Label")
            empty:SetText(L["No leads yet. Replies like \"maybe later\" or \"tell me more\" are saved here automatically."])
            empty:SetFullWidth(true)
            list:AddChild(empty)
        end
        local first = (state.page - 1) * PAGE_SIZE + 1
        for i = first, min(first + PAGE_SIZE - 1, #leads) do
            AddRow(leads[i])
        end

        pageLabel:SetText(format(L["Page %d / %d (%d leads)"], state.page, pages, #leads))
        prevButton:SetDisabled(state.page <= 1)
        nextButton:SetDisabled(state.page >= pages)
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

    templateDropdown:SetCallback("OnValueChanged", function(_, _, value)
        state.templateId = value
        widgets.Refresh()
    end)
    prevButton:SetCallback("OnClick", function()
        state.page = state.page - 1
        widgets.Refresh()
    end)
    nextButton:SetCallback("OnClick", function()
        state.page = state.page + 1
        widgets.Refresh()
    end)

    -- A new lead arrives while the tab is open
    GRB.Leads.onUpdate = widgets.Refresh

    RefreshTemplates()
    widgets.Refresh()
end

local function Cleanup()
    GRB.Leads.onUpdate = nil
end

GRB.MainFrame:RegisterTab("Leads", L["Leads"], Build, Cleanup)
