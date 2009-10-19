DKP = {}

local sortDirs = {}

LEADERBOARD_COUNT = 10

function DKP:Command (cmd)
   local commands = GUtil:ParseCommands(cmd)
   local firstWord = commands[1];

   GUtil:Debug("DKP:Command [cmd=" .. cmd .. "].")

   if GUtil:Blank(cmd) then
      DKP:PrintHelp()

   elseif (cmd == "on") then
      DKP:DoEnableLookups()

   elseif (cmd == "off") then
      DKP:DoDisableLookups()

   else
      -- mod-runner is looking up dkp for someone or some group set
      DKP:DoLookupDKP(cmd)
   end
end

function DKP:DoDisableLookups ()
   GUtil:Print("Disabled DKP lookups.")
   GM_Config["DKP_Lookups"] = false
end

function DKP:DoDisableShowZeroPlayers ()
   GUtil:Print("Disabled showing of zero-dkp players in DKP list.")
   GM_Config["DKP_ShowZero"] = false
end

function DKP:DoEnableLookups ()
   GUtil:Print("Enabled DKP lookups.")
   GM_Config["DKP_Lookups"] = true
end

function DKP:DoEnableShowZeroPlayers ()
   GUtil:Print("Enabled showing of zero-dkp players in DKP list.")
   GM_Config["DKP_ShowZero"] = true
end

function DKP:DoLookupDKP (name, requestor)
--    local safeRequestor = requestor
--    if not safeRequestor then
--       safeRequestor = "nil"
--    end
--    GUtil:Debug("Look up DKP [name=" .. name .. ", safeRequestor=" .. 
--                safeRequestor .. "].")

   -- don't allow dkp lookups if they're disabled
   if (not GM_Config["DKP_Lookups"]) then
      DKP:ReportMessage(requestor, "Can't look up DKP as lookups are " ..
                        "currently disabled.")
      return
   end

   -- make sure we actually have dkp data present
   if (not UDKP_DKP_LastUpdate) then
      DKP:ReportMessage(requestor, "No DKP data available.")
      return
   end

   -- report date of current dkp data
   DKP:ReportMessage(requestor, "DKP info last updated " .. 
                     UDKP_DKP_LastUpdate .. ".")

   -- report usage if no name/dkp-set to look up
   if (not name) then
      DKP:ReportMessage(requestor, "Usage: dkp <player/class/all/boss/raid>")
      return
   end

   name = string.lower(name)

   -- build up the names of all players to look up for the requested
   -- dkp set
   local raid_players_cache = { };

   if (string.find(name, "^raid")) then
      if (GetNumRaidMembers() == 0) then
         GUtil:PrintError("You're not in a raid.")
         return
      end

      -- gather all names of players in the current raid
      for i = 1, GetNumRaidMembers(), 1 do
         raid_players_cache[UnitName("raid"..i)] = 1;
      end

   elseif (string.find(name, "^boss")) then
      -- legacy hack to deal gracefully with dkp request for common
      -- zones.  we probably don't need this any more but we leave it
      -- for now.
      local zone = GetRealZoneText();
      if (zone == "Onyxia's Lair" or 
          zone == "Blackwing Lair" or 
          zone == "Molten Core" or 
          zone == "Naxxramas") then
         DKP:ReportMessage(requestor, "DKP for " .. zone)

         for k, v in pairs(UDKP_Events) do
            if (v["zone"] == zone) then
               DKP:ReportMessage(requestor, v["name"] .. " : " .. v["dkp"])
            end
         end

      else
         -- output dkp info for all matching snapshot events
         for k, v in pairs(UDKP_Events) do
            if (strlen(v["zone"]) == 0) then
               DKP:ReportMessage(requestor, v["name"] .. " : " .. v["dkp"])
            end
         end
      end

      return
   end

--    GUtil:Debug("Looking up DKP [name=" .. name .. 
--                ", playerCount=" .. table.getn(UDKP_Players) .. "].")

   -- sort player list by dkp descending
   local dkpSort = 
      function(a, b) return tonumber(a["dkp"]) > tonumber(b["dkp"]) end
   table.sort(UDKP_Players, dkpSort);

   -- report dkp for the specified player or set of players
   local found = 0;
   for k, player in pairs(UDKP_Players) do
      if ((string.lower(player["class"]) == name) or 
          (string.lower(player["name"]) == name) or 
          (name == "all") or 
          (name == "raid" and raid_players_cache[player["name"]] == 1)) then
         DKP:ReportMessage(requestor, GUtil:Capitalize(player["name"]) .. 
                           " : " .. player["dkp"])
         found = found + 1;

         -- only return top leaderboard
         if (found == LEADERBOARD_COUNT) then
            return;
         end
      end
   end

   -- nobody found
   if (found == 0) then
      DKP:ReportMessage(requestor, "Unknown user or group: " .. name .. ".")
   end
end

function DKP:GetShowPlayerList ()
   if (GM_Config["DKP_ShowZero"]) then
      return UDKP_Players

   else
      -- build a new table containing only players with non-zero dkp 
      local ftable = {}
      for k, v in pairs(UDKP_Players) do
         if (tonumber(v["dkp"]) > 0) then
            tinsert(ftable, v)
         end
      end
      return ftable
   end
end

function DKP:GetSortComparator ()
   local sortField = GuildomaticDKPTabFrame.sortType

   local sfunc = nil
   if (sortField == "dkp") then
      sfunc = function (a, b)
                local aval = tonumber(a[sortField])
                local bval = tonumber(b[sortField])
                if (aval == bval) then
                   return a["name"] < b["name"]
                else
                   return aval < bval
                end
             end

   elseif (sortField ~= "name") then
      sfunc = function (a, b)
                if (a[sortField] == b[sortField]) then
                   return (a["name"] < b["name"])

                else
                   return (a[sortField] < b[sortField])
                end
             end
   else
      sfunc = function (a, b) return a[sortField] < b[sortField] end
   end

   local reverse = (GuildomaticDKPTabFrame.sortDir and 
                    GuildomaticDKPTabFrame.sortDir == "desc")
   if (reverse) then return GUtil:ReverseComparator(sfunc) else return sfunc end
end

function DKP:OnDKPEntryClick (button)
   GUtil:Debug("DKP entry clicked [id=" .. this:GetID() .. "].")
   GuildomaticDKPTabFrameScrollBar.selectedEntry = 
      getglobal("DKPEntry" .. this:GetID()).entryIndex;

   DKP:UpdateScrollBar();
end

function DKP:OnLoad ()
   GuildomaticDKPTabFrame.sortType = "name"
end

function DKP:OnShow ()    
--    GUtil:Debug("DKP:OnShow");

   DKP:UpdateScrollBar();
end

function DKP:OnSortColumnClicked (sortType)
   -- allow flipping sort direction or restoring previous direction by column
   GuildomaticDKPTabFrame.sortDir =
      GUtil:UpdateSortDirection(sortDirs, GuildomaticDKPTabFrame.sortType, 
                                sortType)

   -- note the newly specified sort column
   GuildomaticDKPTabFrame.sortType = sortType   

   -- refresh the view
   DKP:UpdateScrollBar();
end

function DKP:OnVariablesLoaded ()
--    GUtil:Debug("DKP:OnVariablesLoaded")
end

function DKP:OnWhisper (msg, param, cmd, requestor, commands)
   if (string.lower(cmd) == "dkp") then
      local _, _, params = string.find(msg, "[^%s]+ ?(.*)");
      DKP:DoLookupDKP(params, requestor);
      return true
   end

   return false
end

function DKP:PrintHelp ()
   Guildomatic:PrintHelpLine("dkp", "<name/class/all/raid> [check dkp]")
   Guildomatic:PrintHelpLine("dkp", "<on/off> [enable/disable dkp lookups]")
end

function DKP:ReportMessage (requestor, msg)
   if (requestor) then
      GUtil:SendChatMessage(requestor, msg)
   else
      GUtil:Print(msg)
   end
end

function DKP:SetHeaderWidth (frame, width)
   frame:SetWidth(width);
   getglobal(frame:GetName().."Middle"):SetWidth(width - 9);
end

function DKP:UpdateScrollBar ()
   local offset = FauxScrollFrame_GetOffset(GuildomaticDKPTabFrameScrollBar)
   local playerList = DKP:GetShowPlayerList()
   local totalRowCount = table.getn(playerList)
   local rowHeight = 16
   local displayRowCount = 20

   -- GUtil:Debug("Updating scrollbar [offset=" .. offset .. "].")
   FauxScrollFrame_Update(GuildomaticDKPTabFrameScrollBar, totalRowCount,
                          displayRowCount, rowHeight);

   -- sort the table by name
   table.sort(playerList, DKP:GetSortComparator())

   for line = 1, displayRowCount do
      index = offset + line;
      local buttonName = "DKPEntry" .. line;
      button = getglobal(buttonName);
--       GUtil:Debug("Fetching button [name=DKPEntry" .. line .. "].");

      if (button ~= nil) then
--          GUtil:Debug("Found button.");
         button.entryIndex = index;

         local playerInfo = playerList[index];
         if (playerInfo ~= nil) then
            getglobal(buttonName .. "Name"):SetText(playerInfo["name"]);
            getglobal(buttonName .. "Class"):SetText(playerInfo["class"]);
            getglobal(buttonName .. "DKP"):SetText(playerInfo["dkp"]);
         end

         if (GuildomaticDKPTabFrameScrollBar.selectedEntry == index) then
            button:LockHighlight();

         else
            button:UnlockHighlight();
         end

         if (index > totalRowCount) then
            button:Hide();

         else
            button:Show();
         end
      end
   end
end
