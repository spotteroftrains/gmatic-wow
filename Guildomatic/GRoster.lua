Roster = {}

local sortDirs = {}

function Roster:Command (cmd)
   GUtil:Debug("Roster:Command [cmd=" .. cmd .. "].")

   -- the only command right now is to record the current roster
   Roster:Record()
end
 

function Roster:GetSize ()
    return table.getn(UDKP_GuildRoster)
end

function Roster:GetSortComparator ()
   local sortField = GuildomaticRosterTabFrame.sortType
   local sfunc = nil

   if (sortField == "rank") then
      -- we actually want to sort by rank index, rather than by rank
      -- name, since that's what user expects as that's what the guild
      -- roster window does
      sfunc = function (a, b)
                if (a["rank_index"] == b["rank_index"]) then
                   return (a["name"] < b["name"])

                else 
                   return (a["rank_index"] < b["rank_index"]) 
                end
             end

   elseif (sortField ~= "name") then
      -- after sorting by the primary field, sort within each by name
      sfunc = function (a, b)
                if (a[sortField] == b[sortField]) then 
                   return (a["name"] < b["name"])

                else 
                   return (a[sortField] < b[sortField]) 
                end
             end

   else
      -- we're just sorting by name
      sfunc = function (a, b) return a[sortField] < b[sortField] end
   end

   local reverse = (GuildomaticRosterTabFrame.sortDir and 
                    GuildomaticRosterTabFrame.sortDir == "desc")
   if (reverse) then return GUtil:ReverseComparator(sfunc) else return sfunc end
end

function Roster:OnLoad ()
   GuildomaticRosterTabFrame.sortType = "name"
end

function Roster:OnRosterEntryClick (button)
   GUtil:Debug("Roster entry clicked [id=" .. this:GetID() .. "].")
   GuildomaticRosterTabFrameScrollBar.selectedEntry = 
      getglobal("RosterEntry" .. this:GetID()).entryIndex;

   Roster:UpdateScrollBar();
end

function Roster:OnShow ()    
   Roster:UpdateStatus()
end

function Roster:OnSortColumnClicked (sortType)
   -- allow flipping sort direction or restoring previous direction by column
   GuildomaticRosterTabFrame.sortDir =
      GUtil:UpdateSortDirection(sortDirs, GuildomaticRosterTabFrame.sortType, 
                                sortType)

   -- note the newly specified sort column
   GuildomaticRosterTabFrame.sortType = sortType

   -- refresh the view
   Roster:UpdateScrollBar();
end

function Roster:OnVariablesLoaded ()
   Roster:UpdateStatus();
end

function Roster:Record ()
    if (not IsInGuild()) then
        GUtil:Print("No roster to record as you're not in a guild.")
        return
    end

    -- request a guild roster info update
    GuildRoster();

    UDKP_GuildRoster = {}

    -- get the player's current guild name
    local guildName = GetGuildInfo("player")

    -- get detailed guild member info for each member
    local num = 0
    local memberCount = GetNumGuildMembers(true);
    for i = 1, memberCount, 1 do
       local gName, gRank, gRankIndex, gLevel, gClass, gZone, gNote, gOfficerNote, gOnline, gStatus, gClassFileName = GetGuildRosterInfo(i)

       -- note each member's info as a new row in our global roster data
       tinsert(UDKP_GuildRoster, 1, 
               { 
                  ["name"] = gName, 
                  ["rank"] = gRank, 
                  ["rank_index"] = gRankIndex,
                  ["level"] = gLevel, 
                  ["class"] = gClass, 
                  ["class_file"] = gClassFileName,
                  ["note"] = gNote
               })

       num = num + 1
    end

    -- note the guild name associated with the roster data
    GM_Config["RosterGuildName"] = guildName

    -- and the time at which roster was last snapped
    GM_Config["RosterSnapAt"] = GUtil:GetDateTime()

    -- refresh the roster view display
    Roster:UpdateStatus()

    GUtil:Print("Recorded " .. num .. " guild members in " .. guildName .. 
                " at " .. GM_Config["RosterSnapAt"] .. ".")
 end

function Roster:SetHeaderWidth (frame, width)
   frame:SetWidth(width);
   getglobal(frame:GetName().."Middle"):SetWidth(width - 9);
end

function Roster:UpdateStatus ()
   -- show latest member count
   local guildName = (GM_Config['RosterGuildName'] or "Unknown")
   GuildomaticRosterTabFrameMemberCount:SetText(Roster:GetSize() .. " members in " .. guildName .. ".")

   -- and the time the roster was last snapshotted
   local msg = "Roster not recorded."
   if (GM_Config['RosterSnapAt']) then
      msg = "Recorded at " .. GM_Config['RosterSnapAt'] .. "."
   end
   GuildomaticRosterTabFrameSnappedAt:SetText(msg)

   -- and update the scrolling member list display
   Roster:UpdateScrollBar()
end

function Roster:UpdateScrollBar ()
   local offset = FauxScrollFrame_GetOffset(GuildomaticRosterTabFrameScrollBar)
   local totalRowCount = Roster:GetSize();
   local rowHeight = 16
   local displayRowCount = 18

   -- GUtil:Debug("Updating scrollbar [offset=" .. offset .. "].")
   FauxScrollFrame_Update(GuildomaticRosterTabFrameScrollBar, totalRowCount,
                          displayRowCount, rowHeight);

   -- sort the table by the configured column
   table.sort(UDKP_GuildRoster, Roster:GetSortComparator())

   for line = 1, displayRowCount do
      index = offset + line;
      local buttonName = "RosterEntry" .. line;
      button = getglobal(buttonName);
      -- GUtil:Debug("Fetching button [name=RosterEntry" .. line .. "].");

      if (button ~= nil) then
         -- GUtil:Debug("Found button.");
         button.entryIndex = index;

         local memberInfo = UDKP_GuildRoster[index];
         if (memberInfo ~= nil) then
            -- fill in the text for this member in each field in the row
            getglobal(buttonName .. "Name"):SetText(memberInfo["name"]);
            getglobal(buttonName .. "Rank"):SetText(memberInfo["rank"]);
            getglobal(buttonName .. "Lvl"):SetText(memberInfo["level"]);
            getglobal(buttonName .. "Class"):SetText(memberInfo["class"]);

            -- set the class text field color based on the class
            local classFileName = memberInfo["class_file"];
            local classTextColor = NORMAL_FONT_COLOR;
            if (classFileName) then
               classTextColor = RAID_CLASS_COLORS[classFileName];
            end
            getglobal(buttonName .. "Class"):SetTextColor(classTextColor.r,
                                                          classTextColor.g,
                                                          classTextColor.b);
         end

         if (GuildomaticRosterTabFrameScrollBar.selectedEntry == index) then
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
