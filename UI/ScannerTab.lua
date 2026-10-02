local GRB = GuildRecruitmentBuddy
local L = GRB.L

local AceGUI = LibStub("AceGUI-3.0")
local Scanner = GRB.Scanner
local Contacts = GRB.Contacts

local PAGE_SIZE = 8
local MAX_LEVEL = 60

local state = {
    page = 1,
    templateId = nil,
}

local ticker       -- repeating timer that keeps the throttle countdown current
local summary = "" -- result of the last "whisper all" click

local function Heading(text)
    local heading = AceGUI:Create("Heading")
    heading:SetText(text)
    heading:SetFullWidth(true)
    return heading
end

local function ClassColored(text, token)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if not color then return text end
    return format("|cff%02x%02x%02x%s|r", floor(color.r * 255), floor(color.g * 255), floor(color.b * 255), text)
end

-- Eligibility of a scanner result for a whisper, ignoring the session rate limit.
local function RowStatus(result)
    local ok, reason = Contacts:CanContact(result.key)
    if ok then
        local contact = Contacts:Get(result.key)
        if contact and contact.timestamp then
            return format(L["Contacted %s (cooldown over)"], date("%Y-%m-%d", contact.timestamp)), true
        end
        return L["New"], true
    end
    return "|cffff6060" .. reason .. "|r", false
end

local function Build(container)
    container:SetLayout("Fill")
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    container:AddChild(scroll)

    local widgets = {}
    local settings = GRB.db.profile.scanner

    -- Filters ----------------------------------------------------------------
    scroll:AddChild(Heading(L["Scanner"]))

    local intro = AceGUI:Create("Label")
    intro:SetText(L["Finds players without a guild with /who. Blizzard allows one query per click: press Next query repeatedly."])
    intro:SetFullWidth(true)
    scroll:AddChild(intro)

    for _, token in ipairs(GRB.CLASSES) do
        local box = AceGUI:Create("CheckBox")
        box:SetLabel(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token] or token)
        box:SetValue(settings.classes[token] ~= false)
        box:SetRelativeWidth(0.33)
        box:SetCallback("OnValueChanged", function(_, _, value)
            settings.classes[token] = value
        end)
        scroll:AddChild(box)
    end

    local minSlider = AceGUI:Create("Slider")
    local maxSlider = AceGUI:Create("Slider")
    for _, slider in ipairs({ minSlider, maxSlider }) do
        slider:SetSliderValues(1, MAX_LEVEL, 1)
        slider:SetRelativeWidth(0.5)
    end
    minSlider:SetLabel(L["Minimum level"])
    minSlider:SetValue(settings.minLevel)
    maxSlider:SetLabel(L["Maximum level"])
    maxSlider:SetValue(settings.maxLevel)
    minSlider:SetCallback("OnValueChanged", function(_, _, value)
        settings.minLevel = value
        if value > settings.maxLevel then
            settings.maxLevel = value
            maxSlider:SetValue(value)
        end
    end)
    maxSlider:SetCallback("OnValueChanged", function(_, _, value)
        settings.maxLevel = value
        if value < settings.minLevel then
            settings.minLevel = value
            minSlider:SetValue(value)
        end
    end)
    scroll:AddChild(minSlider)
    scroll:AddChild(maxSlider)

    local zoneBox = AceGUI:Create("EditBox")
    zoneBox:SetLabel(L["Zone (optional)"])
    zoneBox:SetText(settings.zone)
    zoneBox:SetRelativeWidth(0.5)
    zoneBox:DisableButton(true)
    zoneBox:SetCallback("OnTextChanged", function(_, _, value) settings.zone = value end)
    scroll:AddChild(zoneBox)

    local templateDropdown = AceGUI:Create("Dropdown")
    templateDropdown:SetLabel(L["Whisper template"])
    templateDropdown:SetRelativeWidth(0.5)
    scroll:AddChild(templateDropdown)

    -- Controls ---------------------------------------------------------------
    local startButton = AceGUI:Create("Button")
    startButton:SetText(L["Start new scan"])
    startButton:SetRelativeWidth(0.3)
    scroll:AddChild(startButton)

    local nextButton = AceGUI:Create("Button")
    nextButton:SetRelativeWidth(0.4)
    scroll:AddChild(nextButton)

    local resetButton = AceGUI:Create("Button")
    resetButton:SetText(L["Reset"])
    resetButton:SetRelativeWidth(0.2)
    scroll:AddChild(resetButton)

    local status = AceGUI:Create("Label")
    status:SetFullWidth(true)
    scroll:AddChild(status)

    -- Results ----------------------------------------------------------------
    scroll:AddChild(Heading(L["Players without a guild"]))

    local whisperAllButton = AceGUI:Create("Button")
    whisperAllButton:SetText(L["Whisper all eligible"])
    whisperAllButton:SetRelativeWidth(0.4)
    scroll:AddChild(whisperAllButton)

    local summaryLabel = AceGUI:Create("Label")
    summaryLabel:SetRelativeWidth(0.58)
    scroll:AddChild(summaryLabel)

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

    local nextPageButton = AceGUI:Create("Button")
    nextPageButton:SetText(">")
    nextPageButton:SetRelativeWidth(0.15)
    scroll:AddChild(nextPageButton)

    -- Behaviour --------------------------------------------------------------
    local function SortedResults()
        local sorted = {}
        for _, result in ipairs(Scanner:GetResults()) do tinsert(sorted, result) end
        table.sort(sorted, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return a.key < b.key
        end)
        return sorted
    end

    local function AddRow(result)
        local statusText, eligible = RowStatus(result)

        local info = AceGUI:Create("Label")
        info:SetText(format("%s  %s %s  |cff999999%s|r\n%s",
            ClassColored(result.name, result.token), result.class or "?", result.level or "?", result.zone or "", statusText))
        info:SetRelativeWidth(0.52)
        list:AddChild(info)

        local whisper = AceGUI:Create("Button")
        whisper:SetText(L["Whisper"])
        whisper:SetRelativeWidth(0.15)
        whisper:SetDisabled(not eligible or not state.templateId)
        whisper:SetCallback("OnClick", function()
            local ok, why = GRB.Whisper:Send(result.key, state.templateId, { class = result.class, level = result.level })
            if not ok then GRB:Print(why) end
            widgets.RefreshResults()
        end)
        list:AddChild(whisper)

        local invite = AceGUI:Create("Button")
        invite:SetText(L["Invite"])
        invite:SetRelativeWidth(0.14)
        invite:SetCallback("OnClick", function()
            GRB.AutoInvite:InviteNow({
                key = result.key,
                target = Contacts:GetWhisperTarget(result.key),
                class = result.class,
                level = result.level,
            }, false)
            widgets.RefreshResults()
        end)
        list:AddChild(invite)

        local block = AceGUI:Create("Button")
        block:SetText(L["Block"])
        block:SetRelativeWidth(0.14)
        block:SetCallback("OnClick", function()
            local contact = Contacts:Get(result.key)
            Contacts:Record(result.key, {
                class = result.class,
                level = result.level,
                status = "do-not-contact",
                timestamp = not (contact and contact.timestamp) and GetServerTime() or nil,
            })
            widgets.RefreshResults()
        end)
        list:AddChild(block)
    end

    function widgets.RefreshResults()
        local sorted = SortedResults()
        local pages = max(1, ceil(#sorted / PAGE_SIZE))
        state.page = min(max(state.page, 1), pages)

        list:ReleaseChildren()
        local first = (state.page - 1) * PAGE_SIZE + 1
        for i = first, min(first + PAGE_SIZE - 1, #sorted) do
            AddRow(sorted[i])
        end

        pageLabel:SetText(format(L["Page %d / %d (%d players)"], state.page, pages, #sorted))
        prevButton:SetDisabled(state.page <= 1)
        nextPageButton:SetDisabled(state.page >= pages)
        whisperAllButton:SetDisabled(#sorted == 0 or not state.templateId)
        summaryLabel:SetText(summary)
    end

    function widgets.RefreshControls()
        local stats = Scanner:GetStats()
        local ok, reason = Scanner:CanRun()
        nextButton:SetDisabled(not ok)
        nextButton:SetText(ok and format(L["Next query (%d left)"], Scanner:GetQueueSize()) or reason)

        local lines = {}
        local nextQuery = Scanner:GetNextQuery()
        if nextQuery then
            tinsert(lines, format(L["Next: %s"], Scanner:DescribeQuery(nextQuery)))
        elseif stats.queries > 0 and not Scanner:IsWaiting() then
            tinsert(lines, L["Scan complete."])
        end
        if stats.queries > 0 then
            tinsert(lines, format(L["Queries: %d. Players seen: %d. Without a guild: %d."], stats.queries, stats.scanned, stats.found))
        end
        if stats.capped > 0 then
            local capped = format(L["%d single-level queries hit the result cap; some players may be missing."], stats.capped)
            tinsert(lines, "|cffffd100" .. capped .. "|r")
        end
        if stats.failed > 0 then
            tinsert(lines, "|cffffd100" .. format(L["%d queries got no response from the server."], stats.failed) .. "|r")
        end
        status:SetText(table.concat(lines, "\n"))
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
        widgets.RefreshResults()
    end)
    startButton:SetCallback("OnClick", function()
        local selected = {}
        local any = false
        for _, token in ipairs(GRB.CLASSES) do
            selected[token] = settings.classes[token] ~= false
            any = any or selected[token]
        end
        if not any then
            GRB:Print(L["Select at least one class."])
            return
        end
        summary = ""
        state.page = 1
        local count = Scanner:Start({
            classes = selected,
            minLevel = settings.minLevel,
            maxLevel = settings.maxLevel,
            zone = settings.zone,
        })
        GRB:Printf(L["Scan prepared: %d queries. Press Next query to run them one by one."], count)
    end)
    nextButton:SetCallback("OnClick", function()
        local ok, why = Scanner:RunNext()
        if not ok then GRB:Print(why) end
    end)
    resetButton:SetCallback("OnClick", function()
        summary = ""
        Scanner:Reset()
    end)
    prevButton:SetCallback("OnClick", function()
        state.page = state.page - 1
        widgets.RefreshResults()
    end)
    nextPageButton:SetCallback("OnClick", function()
        state.page = state.page + 1
        widgets.RefreshResults()
    end)
    -- One click sends as many whispers as the session rate limit allows.
    whisperAllButton:SetCallback("OnClick", function()
        local sent, stopped = 0, nil
        for _, result in ipairs(SortedResults()) do
            local _, eligible = RowStatus(result)
            if eligible then
                local ok, why = GRB.Whisper:Send(result.key, state.templateId, { class = result.class, level = result.level })
                if ok then
                    sent = sent + 1
                else
                    stopped = why
                    break
                end
            end
        end
        summary = format(L["Whispered %d player(s)."], sent)
        if stopped then
            summary = summary .. " " .. stopped
        end
        widgets.RefreshResults()
    end)

    Scanner.onUpdate = function()
        widgets.RefreshControls()
        widgets.RefreshResults()
    end
    ticker = GRB:ScheduleRepeatingTimer(function() widgets.RefreshControls() end, 0.5)

    RefreshTemplates()
    widgets.RefreshControls()
    widgets.RefreshResults()
end

local function Cleanup()
    Scanner.onUpdate = nil
    if ticker then
        GRB:CancelTimer(ticker)
        ticker = nil
    end
end

GRB.MainFrame:RegisterTab("Scanner", L["Scanner"], Build, Cleanup)
