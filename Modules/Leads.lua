local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Leads = GRB:NewModule("Leads", "AceEvent-3.0")
GRB.Leads = Leads

-- A reply from a player the addon contacted that sounds interested but not ready ("maybe later", "not yet", "tell me
-- more") is a lead: the player is marked with the Lead status and the reply is kept (Contacts:AddReply, saved for
-- every reply) so it does not get lost in the chat log. Leads are never pruned or purged and are listed in the
-- Leads tab. Replies that are opt-outs are never leads.
local function Settings()
    return GRB.db.profile.leads
end

-- Returns the phrase that matched, or nil. Phrases match as whole words anywhere in the reply.
function Leads:Match(text)
    local optOut = GRB.OptOut
    local message = optOut.Normalize(text or "")
    if message == "" then return nil end
    for _, phrase in ipairs(optOut.ParsePhrases(Settings().phrases)) do
        if optOut.Contains(message, phrase) then return phrase end
    end
    return nil
end

function Leads:OnWhisper(_, text, sender)
    if not Settings().enabled then return end

    local contact, key = GRB.Contacts:Get(sender)
    -- Only players we contacted who have not been handled yet
    if not contact or (contact.status ~= "contacted" and contact.status ~= "replied") then return end
    if GRB.OptOut:Match(text) or GRB.OptOut:IsPending(key) then return end
    if not self:Match(text) then return end

    GRB.Contacts:SetLead(key, text)
    GRB:Printf(L["%s replied \"%s\": saved as a lead."], contact.name or key, text)
    if self.onUpdate then self.onUpdate() end
end

function Leads:OnEnable()
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
end