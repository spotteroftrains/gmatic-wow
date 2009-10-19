GCalendar = {}

local UDKP_ConvertToRaidOnJoin = false;

function GCalendar:Command (cmd)
   local commands = GUtil:ParseCommands(cmd)
   local firstWord = commands[1];
   GUtil:Debug("GCalendar:Command [cmd=" .. cmd .. "].")

   if GUtil:Blank(cmd) then
      GCalendar:PrintHelp()

   elseif (firstWord == "info") then
      GCalendar:DoDisplayEvent(commands)

   elseif (firstWord == "invite") then
      GCalendar:DoInviteEvent(commands)

   elseif (firstWord == "list") then
      GCalendar:DoListEvents()

   elseif (firstWord == "sync") then
      GCalendar:DoSyncEvent(commands)
   end
end

function GCalendar:DoDisplayEvent (commands)
   local eventIndex = tonumber(commands[2])
   if (eventIndex) then
      event = UDKP_Calendar_Events[eventIndex];
      if (event) then
         GUtil:Print(HIGHLIGHT_FONT_COLOR_CODE .. 
                     "Calendar event info for event #" .. eventIndex)
         GUtil:Print(" - " .. event["title"]);
         GUtil:Print(" - " .. event["date"]);
         
         num_accepted = table.getn(event["accepted"]);
         GUtil:Print(" - Accepted Signups [" .. num_accepted .. "]");
         if (num_accepted > 0) then
            GUtil:Print(table.concat(event["accepted"], ", "));
         end

         num_queued = table.getn(event["queued"]);
         GUtil:Print(" - Queued Signups [" .. num_queued .. "]");
         if (num_queued > 0) then
            GUtil:Print("    " .. table.concat(event["queued"], ", "));
         end
      else
         GUtil:PrintError("No such event.");
      end

   else
      GUtil:PrintError("Event # is required for this command.");
   end
end

function GCalendar:DoInviteEvent (commands)
   local param = commands[2]
   local eventIndex = tonumber(commands[3])
   
   if (param and eventIndex) then
      -- look up the event
      event = UDKP_Calendar_Events[eventIndex];
      if (not event) then
         GUtil:PrintError("No such event.");
         return;
      end
      
      if (GetNumRaidMembers() == 0) then
         if (GetNumPartyMembers() > 0) then
            ConvertToRaid();
         else
            -- set the flag to convert to a raid as soon as we're in a party
            UDKP_ConvertToRaidOnJoin = true;
         end
      end
      
      GUtil:Print("Inviting " .. param .. " signups for " .. 
                  HIGHLIGHT_FONT_COLOR_CODE .. 
                  event["title"] .. " " .. 
                  event["date"] .. NORMAL_FONT_COLOR_CODE .. ".");

      if (param == "accepted" or param == "queued") then
         local signups = GCalendar:FilterSignups(event[param]);
         GCalendar:InviteSignups(signups);

      elseif (param == "all") then
         local signups = GCalendar:FilterSignups(event["accepted"]);
         signups = GCalendar:FilterSignups(event["queued"]);
         GCalendar:InviteSignups(signups);
      end

      return;
   end
   
   -- if we fell through to here, something bad happened
   GUtil:PrintError("Usage: " .. HIGHLIGHT_FONT_COLOR_CODE .. 
                    "/gt cal invite <all|accepted|queued> <event #> " .. 
                    RED_FONT_COLOR_CODE .. ".")
end

function GCalendar:DoListEvents ()
   if (table.getn(UDKP_Calendar_Events) == 0) then
      GUtil:Print("No calendar events.")
      return
   end

   for k, v in pairs(UDKP_Calendar_Events) do
      num_accepted = table.getn(v["accepted"])
      num_queued = table.getn(v["queued"])

      GUtil:Print(HIGHLIGHT_FONT_COLOR_CODE .. 
                  k .. ". " .. 
                  NORMAL_FONT_COLOR_CODE .. 
                  v["date"] .. " " .. 
                  v["title"] .. 
                  " [" .. num_accepted + num_queued .. " signups].")
    end
end

function GCalendar:DoSyncEvent (commands)
   local eventIndex = tonumber(commands[2])

   if (eventIndex) then
      event = UDKP_Calendar_Events[eventIndex];

      if (event) then
         GUtil:Print(HIGHLIGHT_FONT_COLOR_CODE ..
                     "Syncing calendar event #" .. eventIndex)
         GUtil:Print(" - " .. event["title"]);
         GUtil:Print(" - " .. event["date"]);

         -- parse out the time
         local _, _, mm, dd, yyyy, hh, min = 
            string.find(event["date"], "(%d+)/(%d+)/(%d+) (%d+):(%d+)");
         
         if (not mm) then
            GUtil:PrintError("Couldn't parse date. Please re-download the " ..
                             "static file.");
            return;
         end
         
         -- sync this info into the in-game WoW calendar by creating a
         -- new event if the user syncs twice, they'll have two
         -- events, maybe we should delete the old one in the future?
         CalendarNewGuildEvent();

         -- only default to raids for now
         CalendarEventSetType(CALENDAR_EVENTTYPE_RAID);
         CalendarEventSetTitle(event["title"]);
         CalendarEventSetDescription("Synced from Guildomatic module data " ..
                                     "[" .. UDKP_DKP_LastUpdate .. "].")
         CalendarEventSetDate(mm, dd, yyyy);
         CalendarEventSetTime(hh, min);

         -- save this event before we issue out invites
         CalendarAddEvent();
         
         -- we'd actually sync invites if blizzard didn't require a
         -- hardware event for the CalendarEventInvite() API call
         -- GCalendar:SyncInvites(eventIndex);
         
         GUtil:Print(HIGHLIGHT_FONT_COLOR_CODE .. 
                     "Calendar event successfully synced.")

      else
         GUtil:PrintError("No such event.");
      end

   else
      GUtil:PrintError("Event # is required for this command.");
   end
end

function GCalendar:FilterSignups (signups)
   local new_signups = {};
   local filter_members = {};

   -- if we're in a party or a raid, remove the members from the
   -- signups to invite
   if (signups and table.getn(signups) > 0) then
      -- we'll never invite ourself
      filter_members[UnitName("player")] = "1";
      if (GetNumRaidMembers() > 0) then
         for i = 1, GetNumRaidMembers(), 1 do
            filter_members[UnitName("raid" .. i)] = "1";
         end

      elseif (GetNumPartyMembers() > 0) then
         for i = 1, GetNumPartyMembers(), 1 do
            filter_members[UnitName("party" .. i)] = "1";
         end
      end

      for k, v in pairs(signups) do
         if (not filter_members[v]) then
            table.insert(new_signups, v)
         end
      end
   end
   
   return new_signups;
end

function GCalendar:InviteSignups (signups)
   if (table.getn(signups) == 0) then
      GUtil:PrintError("No valid signups to invite.");

   else
      for k, v in pairs(signups) do
         InviteUnit(v);
      end
   end
end

function GCalendar:OnPartyMembersChanged ()
   if ((UDKP_ConvertToRaidOnJoin == true) and 
       (GetNumRaidMembers() == 0) and 
       (GetNumPartyMembers() > 0)) then
      ConvertToRaid();
      UDKP_ConvertToRaidOnJoin = false;
   end
end

function GCalendar:PrintHelp ()
   Guildomatic:PrintHelpLine("cal list", "[list calendar events]")
   Guildomatic:PrintHelpLine("cal info", "<event #> [display event info]")
   Guildomatic:PrintHelpLine("cal sync", 
                             "<event #> [sync calendar event to in-game " ..
                              "calendar]")
   Guildomatic:PrintHelpLine("cal invite",
                             "<all|accepted|queued> " ..
                             "[invite selected signups to group]")
end

-- this doesn't work right now due to Blizzard/taint/API issues preventing mass
-- invites
-- function GCalendar:SyncInvites (eventIndex)
--    if (eventIndex) then
--       event = UDKP_Calendar_Events[eventIndex];
--       if (event) then
--          local signups = GCalendar:FilterSignups(event["accepted"]);
--          signups = GCalendar:FilterSignups(event["queued"]);
--          for k, player in pairs(signups) do
--             CalendarEventInvite(player);
--          end
--       end
--    end
-- end
