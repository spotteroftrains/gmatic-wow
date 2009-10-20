GRaids = {}

local sortDirs = {}

-- map loot item quality names to their index
local UDKP_SnapshotQualityMap = {
    ["poor"] = 0,
    ["common"] = 1,
    ["uncommon"] = 2,
    ["rare"] = 3,
    ["epic"] = 4,
    ["legendary"] = 5,
    ["artifact"] = 6
};

-- map loot item color rgb values to their index
local UDKP_LootColorMap = {
    ["ff9d9d9d"] = 0, -- grey
    ["ffffffff"] = 1, -- white
    ["ff1eff00"] = 2, -- green
    ["ff0070dd"] = 3, -- blue
    ["ffa335ee"] = 4, -- purple
    ["ffff8000"] = 5, -- orange
    ["ffff0000"] = 6  -- red
}
 
local selectedSnap = nil
local selectedLoot = nil

function GRaids:Command (cmd)
   local commands = GUtil:ParseCommands(cmd)
   local firstWord = commands[1];

   GUtil:Debug("GRaids:Command [cmd=" .. cmd .. "].")

   if GUtil:Blank(cmd) then
      GRaids:PrintHelp()

   elseif (cmd == "clear") then
      GRaids:DoClearAllSnapshots()

   elseif (firstWord == "ignore") then
      GRaids:CommandIgnore(cmd, commands)

   elseif (cmd == "list") then
      GRaids:DoListSnapshots()

   elseif (firstWord == "loot") then
      local lootQuality = commands[2]
      GRaids:SetMinimumLootQuality(lootQuality)

   elseif (firstWord == "note") then
      local snapNo = commands[2]
      local itemNo = commands[3]
      local note = commands[4]
      GRaids:SetLootNote(snapNo, itemNo, note)

   elseif (firstWord == "remove") then
      local snapNo = commands[2]
      GRaids:DoRemoveSnapshot(snapNo)

   else
      GRaids:DoBossSnapshot(cmd)
   end
end

function GRaids:CommandIgnore (cmd, commands)
   local subCommand = commands[2]

   if (subCommand == "remove") then
      -- handle remove ignored item name
      GRaids:DoLootIgnoreRemove(cmd, commands)

   elseif (subCommand == "list") then
      -- list currently ignored items
      GRaids:DoLootIgnoreList()

   elseif (subCommand == "clear") then
      -- clear ignored items
      GRaids:DoLootIgnoreClear()

   elseif (subCommand) then
      -- attempt to add a new ignored item
      -- TODO: should this require "add" explicit subcommand?
      GRaids:DoLootIgnoreAdd(cmd)

   else
      -- print ignore help sub-menu
      GRaids:PrintLootIgnoreHelp()
   end
end

function GRaids:DoBossSnapshot (cmd)
   -- TODO: fix parsing to work with obscure boss names that old
   -- mod failed to parse properly; need to dig up examples
   local _, _, name, dkp = string.find(cmd, "^(.+) (.+)$");
   if (not name or not dkp) then
      GUtil:PrintError("Invalid snapshot command.");

   else
      GRaids:TakeSnapshot(name, dkp);
   end
end

function GRaids:DoClearAllSnapshots ()
   UDKP_Snapshots = { };
   GUtil:Print("Cleared all snapshots.")

   GRaids:PopulateSnapFields();
   GRaids:UpdateScrollBar();
end

function GRaids:DoListSnapshots ()
   local num = 0;
   local snaps = GRaids:GetSnapsBySnapTime()

   for k, v in pairs(snaps) do
      local snapshot_time;
      if (v["utc_time"]) then
         snapshot_time = date("%x %X", v["utc_time"]);
      else
         snapshot_time = v["time"];
      end

      GUtil:Print(k .. ". " .. v["event"] .. " - " .. snapshot_time);
      if (v["loot"]) then
         for l, w in pairs(v["loot"]) do
            local line = "  " .. 
               l .. ". " .. 
               w["player"] .. " - " .. 
               w["item"];

            -- only show the " - 42 DKP" after item in list if there
            -- was actually a dkp-note attached to the item
            if (not GUtil:Blank(w["note"]) and w["note"] ~= "-") then
               line = (line .. " - " .. w["note"] .. " DKP")
            end

            GUtil:Print(line);
         end
      end
      num = num + 1;
   end

   if (num == 0) then
      GUtil:Print("No snapshots.");
   end
end

function GRaids:DoLootIgnoreAdd (cmd)
   -- TODO: we should really store loot uniquely, in a set or
   -- otherwise making sure any given item is only in the list once
   local _, _, item = string.find(cmd, "^ignore (.+)$");
   item = GUtil:trim(item)
   GUtil:Print("Added " .. item .. " to loot ignore list.");
   tinsert(GM_Config["IgnoredLoot"], 1, { ["item"] = item });
end

function GRaids:DoLootIgnoreClear ()
   GM_Config["IgnoredLoot"] = {};
   GUtil:Print("Cleared loot ignore list.");
end

function GRaids:DoLootIgnoreList ()
   local num = 0;

   GUtil:Print("Loot to ignore:");
   if (GM_Config["IgnoredLoot"]) then
      for k, v in pairs(GM_Config["IgnoredLoot"]) do
         GUtil:Print(k .. ". " .. v["item"]);
         num = num + 1;
      end
   end

   if (num == 0) then
      GUtil:Print("None.");
   end
end

function GRaids:DoLootIgnoreRemove (cmd, commands)
   if (commands[3]) then
      local _, _, item = string.find(cmd, "^ignore remove (.+)$");
      item = GUtil:trim(item)

      local found = 0;
      for k, v in pairs(GM_Config["IgnoredLoot"]) do
         if (strlower(v["item"]) == strlower(item)) then
            tremove(GM_Config["IgnoredLoot"], k);
            GUtil:Print("Removed " .. item .. " from loot ignore list.")
            found = 1;
         end
      end

      if (found == 0) then
         GUtil:PrintError(item .. " not found in loot ignore list.")
         return false;
      end

      return true;
   end

   GUtil:PrintError("Invalid loot ignore remove command.")
end

function GRaids:DoRemoveSnapshot (snapNo)
   if (not GUtil:Blank(snapNo)) then
      local snum = tonumber(snapNo);
      local snaps = GRaids:GetSnapsBySnapTime()

      if (snum > 0 and snaps and table.getn(UDKP_Snapshots) >= snum) then
         local rmIndex = snaps[snum]["base_snap_index"]
         tremove(UDKP_Snapshots, rmIndex)

         -- update the visual display to reflect the change
         selectedSnap = nil
         selectedLoot = nil
         GRaids:UpdateScrollBar()
         GuildomaticSnapDetailFrame:Hide()

         return true
      end

      -- couldn't find the snapshot
      GUtil:PrintError("Snapshot entry " .. snum .. " not found.");
      return false;
   end

   -- no snapshot number specified
   GUtil:PrintError("Invalid snapshot remove command.")
   return false;
end

function GRaids:GetLatestSnapshot ()
   local snaps = GRaids:GetSnapsBySnapTime()
   if (not snaps) then
      return nil
   else
      return snaps[GRaids:GetSize()]
   end
end

function GRaids:GetSize ()
    return table.getn(UDKP_Snapshots)
end

function GRaids:GetSnapsBySnapTime ()
   -- build a list of all snaps sorted by snap time
   local snaps = {}
   for key, value in pairs(UDKP_Snapshots) do
      -- note this snap's current index in the base snapshot table so
      -- that the caller can reference it if needed, e.g., for removal
      value["base_snap_index"] = key
      table.insert(snaps, value)
      table.sort(snaps, function (a, b) return a["utc_time"] < b["utc_time"] end);
   end
   return snaps
end

function GRaids:GetSortComparator ()
   local sortField = GuildomaticRaidsTabFrame.sortType

   local sfunc = nil
   if (sortField == "playerCount") then
      -- sort by player count, and within equal count, by event name
      sfunc = function (a, b)
                local aCount = table.getn(a["players"])
                local bCount = table.getn(b["players"])
                if (aCount == bCount) then
                   return (a["event"] < b["event"])

                else
                   return (aCount < bCount)
                end
             end

   elseif (sortField == "lootCount") then
      -- sort by loot count, and within equal count, by event name
      sfunc = function (a, b)
                local aCount = table.getn(a["loot"])
                local bCount = table.getn(b["loot"])
                if (aCount == bCount) then
                   return (a["event"] < b["event"])

                else
                   return (aCount < bCount)
                end
             end

   elseif (sortField ~= "event") then
      -- sort by the specified field, and within that, by event name
      sfunc = function (a, b)
                if (a[sortField] == b[sortField]) then
                   return (a["event"] < b["event"])

                else
                   return (a[sortField] < b[sortField])
                end
             end

   else
      -- else we're just sorting by event name
      sfunc = function (a, b) return a[sortField] < b[sortField] end
   end

   local reverse = (GuildomaticRaidsTabFrame.sortDir and 
                    GuildomaticRaidsTabFrame.sortDir == "desc")
   if (reverse) then return GUtil:ReverseComparator(sfunc) else return sfunc end
end

function GRaids:OnClearAllClicked ()
   GRaids:DoClearAllSnapshots();
end

function GRaids:FindSnapshotIndex (allSnaps, soughtSnap)
   for key, snap in pairs(allSnaps) do
      if (snap == soughtSnap) then
         return key
      end
   end

   return nil
end

function GRaids:OnDeleteSelectedSnapshotClicked ()
   local snaps = GRaids:GetSnapsBySnapTime()
   local selectedSnapNo = GRaids:FindSnapshotIndex(snaps, selectedSnap)
   GRaids:DoRemoveSnapshot(selectedSnapNo)
end

function GRaids:OnDetailLootEntryClick (button)
   GUtil:Debug("Detail loot entry clicked [id=" .. this:GetID() .. "].")
   GuildomaticSnapDetailFrameLootScrollBar.selectedEntry = 
      getglobal("DetailLootEntry" .. this:GetID()).entryIndex;

   GRaids:UpdateDetailLootScrollBar()
end

function GRaids:OnDetailPlayerEntryClick (button)
   GUtil:Debug("Detail player entry clicked [id=" .. this:GetID() .. "].")
   GuildomaticSnapDetailFramePlayerScrollBar.selectedEntry = 
      getglobal("DetailPlayerEntry" .. this:GetID()).entryIndex;

   GRaids:UpdateDetailPlayerScrollBar()
end

function GRaids:OnDetailLootSortColumnClicked (sortType)
   -- TODO
end

function GRaids:OnDetailPlayerSortColumnClicked (sortType)
   -- TODO
end

function GRaids:OnHide ()
--    GUtil:Print("GRaids:OnHide")

   -- make sure to hide the snap detail window if present
   GuildomaticSnapDetailFrame:Hide()
end

function GRaids:OnLoad ()
   GuildomaticRaidsTabFrame.sortType = "time"
end

function GRaids:OnRaidEntryClick (button)
   GUtil:Debug("Raid entry clicked [id=" .. this:GetID() .. "].")
   GuildomaticRaidsTabFrameScrollBar.selectedEntry = 
      getglobal("RaidEntry" .. this:GetID()).entryIndex;

   GRaids:UpdateScrollBar();

   GRaids:UpdateSnapDetail()

   GuildomaticSnapDetailFrame:Show()
end

function GRaids:OnShow ()
--    GUtil:Print("GRaids:OnShow")

   GRaids:PopulateSnapFields();
   GRaids:UpdateScrollBar();
end

function GRaids:OnSortColumnClicked (sortType)
   -- allow flipping sort direction or restoring previous direction by column
   GuildomaticRaidsTabFrame.sortDir =
      GUtil:UpdateSortDirection(sortDirs, GuildomaticRaidsTabFrame.sortType, sortType)

   -- note the newly specified sort column
   GuildomaticRaidsTabFrame.sortType = sortType   

   -- refresh the view
   GRaids:UpdateScrollBar();
end

function GRaids:OnVariablesLoaded ()
end

function GRaids:OnTakeSnapshotClicked ()
   -- we should pre-fill the name text field with the most recently
   -- killed boss name; or default to next-snapshot-number
   local snapName = GuildomaticRaidsTabFrameSnapName:GetText();

   -- get snapshot dkp amount from text input field
   local dkpField = GuildomaticRaidsTabFrameSnapDKP:GetText();
   local dkp = tonumber(dkpField);
   if (dkp == nil) then
      dkp = 0;
   end

   -- TODO: we should pre-fill the dkp text field with the dkp amount
   -- for the matching raid snapshot event, if any; default to 0

   -- attempt to take the snapshot with the user-entered info
   GRaids:TakeSnapshot(snapName, dkp)
end

function GRaids:PopulateSnapFields ()
   local defaultSnapName = ""

   -- set the snap name text field contents if currently empty
   local snapNameField = GuildomaticRaidsTabFrameSnapName:GetText();
   GuildomaticRaidsTabFrameSnapName:SetText(defaultSnapName);

   -- TODO: look up dkp value for snap name text field contents?

   -- set the dkp text field contents if currently empty
   local dkpField = GuildomaticRaidsTabFrameSnapDKP:GetText();
   local dkp = tonumber(dkpField);
   GuildomaticRaidsTabFrameSnapDKP:SetText(0);
--    if (dkp == nil) then
--       GuildomaticRaidsTabFrameSnapDKP:SetText(0);
--    end
end

function GRaids:PrintHelp ()
   -- print snapshot-command-specific sub-commands
   Guildomatic:PrintHelpLine("snapshot",
                             "<name> <dkp> [snapshot group members]")
   Guildomatic:PrintHelpLine("snapshot clear", "[delete all snapshots]")
   Guildomatic:PrintHelpLine("snapshot ignore",
                             "<item name> [don't record this loot]")
   Guildomatic:PrintHelpLine("snapshot ignore",
                             "[help for snapshot ignored items]")
   Guildomatic:PrintHelpLine("snapshot list", "[list all snapshots]")
   Guildomatic:PrintHelpLine("snapshot loot",
                             "<quality> [minimum loot quality to record: " ..
                                "poor, common, uncommon, rare, epic, " ..
                                "legendary, artifact]")
   Guildomatic:PrintHelpLine("snapshot note",
                             "<snapshot #> <item #> <note> " ..
                                "[record dkp value for item]")
   Guildomatic:PrintHelpLine("snapshot remove", 
                             "<snapshot #> [remove snapshot entry]")

   -- display current minimum loot quality to record
   for k, v in pairs(UDKP_SnapshotQualityMap) do
      if (v == GM_Config["LootMinQuality"]) then
         GUtil:Print("Currently capturing " .. k .. " quality loot and above.");
         break;
      end
   end
end

function GRaids:PrintLootIgnoreHelp ()
   Guildomatic:PrintHelpLine("snapshot ignore", 
                             "<item> [add item to loot ignore list]")
   Guildomatic:PrintHelpLine("snapshot ignore remove", 
                             "<item> [remove item from loot ignore list]")
   Guildomatic:PrintHelpLine("snapshot ignore list", "[show loot ignore list]")
   Guildomatic:PrintHelpLine("snapshot ignore clear", 
                             "[clear loot ignore list]")
end

function GRaids:RecordLoot (self, event, ...)
   local msg = select(1, ...)

--    GUtil:Debug("Looting " .. msg .. " end.");

   -- parse the player name and item name from the loot message
   local iStart, _, sPlayer, sItem = 
      string.find(msg, "([^%s]+) receive[s]? loot: (.+)%.")

   local recordedLoot = false

   if (iStart) then
      -- parse the loot quality/color from the item name
      local _, _, sColor = string.find(sItem, "|c(%x+)|Hitem:")

      -- make sure the loot is within quality range to capture
      if (sColor and 
          (UDKP_LootColorMap[sColor] >= GM_Config["LootMinQuality"])) then
         -- build definitive receiving player name
         if (sPlayer == "You") then
            sPlayer = UnitName("player")
         end

         local snap = GRaids:GetLatestSnapshot()

         if (not snap) then
            GUtil:Print("Must create snapshot before loot can be " ..
                        "captured.  '/gt snapshot' for help.")
            return false, ...;
         end

         local ignore_loot = nil;

         -- make sure the loot isn't on the list to ignore
         GUtil:Debug("Checking for ignored loot [sItem=" .. sItem .. "].")

         for k, v in pairs(GM_Config["IgnoredLoot"]) do
            --                GUtil:Debug("Testing ignore item [l_sItem='" .. 
            --                            strlower(sItem) .. "', l_vItem='" .. 
            --                            strlower(v["item"]) .. "'].")

            local lStart, lEnd = 
               string.find(strlower(sItem), strlower(v["item"]), 1, true)
            if (lStart) then
               GUtil:Debug("Found ignored item [sItem=" .. sItem .. "].")
               ignore_loot = 1
               break;
            end
         end
         
         if (not ignore_loot) then
            -- it's finally time to actually record the loot
            local loot = snap["loot"]
            if (not loot) then
               tinsert(snap, { ["loot"] = {} })
               loot = snap["loot"]
            end

            local date = GUtil:GetDateTime()
            local utc_time = time()
            tinsert(loot, { 
                       ["player"] = sPlayer, 
                       ["item"] = sItem, 
                       ["time"] = date, 
                       ["utc_time"] = utc_time, 
                       ["note"] = "-" })

            -- let the mod runner know we captured the item so they sleep easy
            GUtil:Print("Recorded " .. sItem .. " looted by " .. sPlayer .. ".")

            -- and note we really recorded it
            recordedLoot = true
         end
      end
   end

   if (recordedLoot) then
      -- update our view to reflect any change in loot count
      GRaids:UpdateScrollBar()
      GRaids:UpdateSnapDetail()
   end

   -- let the rest of the wow interface do as it will
   return false, ...;
end

function GRaids:SetHeaderWidth (frame, width)
   frame:SetWidth(width);
   getglobal(frame:GetName() .. "Middle"):SetWidth(width - 9);
end

function GRaids:SetLootNote (snapNo, itemNo, note)
   if ((not GUtil:Blank(snapNo)) and
       (not GUtil:Blank(itemNo)) and
       (not GUtil:Blank(note))) then
      -- convert snap and item number from string to int
      local snum = tonumber(snapNo);
      local snaps = GRaids:GetSnapsBySnapTime()
      local inum = tonumber(itemNo);

      if (snum and inum) then
         -- look up the snapshot in which note is to be set
         local snapshot = snaps[snum];
         if (not snapshot) then
            GUtil:PrintError("Snapshot " .. snum .. " not found.");
            return false;
         end

         -- look up the item within the snapshot in which note is to be set
         local loot = snapshot["loot"];
         local item = loot[inum];
         if (not item) then
            GUtil:PrintError("Item " .. inum .. " not found in snapshot " .. 
                             snum .. ".");
            return false;
         end

         -- finally, record the note as requested
         item["note"] = note;
         GUtil:Print("Recorded " .. note .. " for " .. item["item"] .. ".");

         GRaids:UpdateSnapDetail()

         return true
      end
   end

   GUtil:PrintError("Invalid loot note command.")
   return false
end

function GRaids:SetMinimumLootQuality (lootQuality)
   if (lootQuality) then
      local qual = string.lower(lootQuality);

      if (UDKP_SnapshotQualityMap[qual]) then
         GM_Config["LootMinQuality"] = UDKP_SnapshotQualityMap[qual];
         GUtil:Print("Now capturing " .. qual .. " loot and up.");
         return true
      end
   end

   GUtil:PrintError("Invalid loot quality. Options: poor, common, " ..
                    "uncommon, rare, epic, legendary, artifact.");
end

function GRaids:SnapshotRecordPlayer (unitid, players)
    local player, online, class = 
      UnitName(unitid), UnitIsConnected(unitid), UnitClass(unitid);

    -- record dkp adjustments for all players in raid that are online,
    -- if you're disconnected, you're SOL
    if (not online) then
        GUtil:Print("Can't record all info as you are disconnected.")

        -- XXX nothing ever checks this below?  should we not insert
        -- data for the player if we're not online?
        online = 0;
    end

    -- XXX dkp and event name and people online
    tinsert(players, { ["name"] = player });

    -- XXX not yet
    --GmaticDKP_RecordDKP(player, tonumber(dkp));
end

function GRaids:TakeSnapshot (snapName, dkp)
    GUtil:Debug("GRaids:TakeSnapshot [snapName=" .. snapName .. 
                ", dkp=" .. dkp .. "].")

    -- make sure we're in a raid/party as prerequisite
    if (GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0) then
        GUtil:PrintError("Can't take snapshot. Not in raid or group.");
        return;
    end

    -- TODO: validate snapName and dkp params
    snapName = GUtil:trim(snapName)
    if (GUtil:Blank(snapName)) then
      snapName = "Unknown"
    end

    -- look up event by string matching first few characters
    local eventName = GUtil:Capitalize(snapName);
    for k, eventTable in pairs(UDKP_Events) do
        local iStart, iEnd = string.find(eventTable["name"], "^" .. eventName);
        if (iStart) then
            eventName = eventTable["name"];
            break;
        end
    end

    local players = { };
    local playerCount = 0;

    if (GetNumRaidMembers() > 0) then
        -- we're in a raid, so take note of each raid member
        playerCount = GetNumRaidMembers();
        for i = 1, playerCount, 1 do
            GRaids:SnapshotRecordPlayer("raid" .. i, players);
        end

     else
        -- we're not in a raid so we must be in a party, so first...

        -- take note of each party member other than ourselves
        playerCount = GetNumPartyMembers();
        for i = 1, playerCount, 1 do
            GRaids:SnapshotRecordPlayer("party" .. i, players);
        end

        -- and then record our own info as well
        GRaids:SnapshotRecordPlayer("player", players);

        -- finally, add one to playerCount as GetNumPartyMembers()
        -- returns player count excluding ourselves and we want to
        -- report *total* number of players below
        playerCount = playerCount + 1;
    end

    -- gather date/time info for this snapshot
    local zone = GetRealZoneText();
    local date = GUtil:GetDateTime();
    local utc_time = time();

    -- insert the record with all info
    tinsert(UDKP_Snapshots, 1, 
            { ["event"] = eventName,
              ["zone"] = zone,
              ["time"] = date,
              ["utc_time"] = utc_time,
              ["dkp"] = dkp,
              ["players"] = players,
              ["loot"] = {} });

    -- inform the user of what we've just done
    GUtil:Print("Awarded " .. dkp .. " DKP for " .. eventName .. " to " .. 
                playerCount .. " players.");

    -- update display to reflect newly added snapshot
    GRaids:PopulateSnapFields();
    GRaids:UpdateScrollBar();
end

function GRaids:UpdateDetailLootScrollBar ()
   local offset = FauxScrollFrame_GetOffset(GuildomaticSnapDetailFrameLootScrollBar)
   local lootCount = table.getn(selectedSnap["loot"])
   local totalRowCount = lootCount
   local rowHeight = 16
   local displayRowCount = 5

   FauxScrollFrame_Update(GuildomaticSnapDetailFrameLootScrollBar, totalRowCount,
                          displayRowCount, rowHeight);

   -- sort the table by the configured column
--    table.sort(UDKP_Snapshots, GRaids:GetSortComparator())

   for line = 1, displayRowCount do
      index = offset + line;
      local buttonName = "DetailLootEntry" .. line;
      button = getglobal(buttonName);
--       GUtil:Print("Fetching button [name=DetailLootEntry" .. line .. "].");

      if (button ~= nil) then
--          GUtil:Print("Found button.");
         button.entryIndex = index;

         local lootInfo = selectedSnap["loot"][index]
         if (lootInfo ~= nil) then
            getglobal(buttonName .. "Name"):SetText(lootInfo["player"]);
            getglobal(buttonName .. "Item"):SetText(lootInfo["item"]);
            getglobal(buttonName .. "Note"):SetText(lootInfo["note"]);
         end

         if (GuildomaticSnapDetailFrameLootScrollBar.selectedEntry == index) then
            selectedLoot = lootInfo
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

function GRaids:UpdateDetailPlayerScrollBar ()
   local offset = FauxScrollFrame_GetOffset(GuildomaticSnapDetailFramePlayerScrollBar)
   local playerCount = table.getn(selectedSnap["players"])
   local totalRowCount = playerCount
   local rowHeight = 16
   local displayRowCount = 5

--    GUtil:Print("Updating detail player [playerCount=" .. playerCount .. "].")
   FauxScrollFrame_Update(GuildomaticSnapDetailFramePlayerScrollBar, totalRowCount,
                          displayRowCount, rowHeight);

   -- sort the table by the configured column
--    table.sort(UDKP_Snapshots, GRaids:GetSortComparator())

   for line = 1, displayRowCount do
      index = offset + line;
      local buttonName = "DetailPlayerEntry" .. line;
      button = getglobal(buttonName);
--       GUtil:Print("Fetching button [name=DetailPlayerEntry" .. line .. "].");

      if (button ~= nil) then
--          GUtil:Print("Found button.");
         button.entryIndex = index;

         local playerInfo = selectedSnap["players"][index]
         if (playerInfo ~= nil) then
            getglobal(buttonName .. "Name"):SetText(playerInfo["name"]);
         end

         if (GuildomaticSnapDetailFramePlayerScrollBar.selectedEntry == index) then
            selectedPlayer = playerInfo
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

function GRaids:UpdateScrollBar ()
   local offset = FauxScrollFrame_GetOffset(GuildomaticRaidsTabFrameScrollBar)
   local totalRowCount = GRaids:GetSize();
   local rowHeight = 16
   local displayRowCount = 16

   -- GUtil:Print("Updating scrollbar [offset=" .. offset .. "].")
   FauxScrollFrame_Update(GuildomaticRaidsTabFrameScrollBar, totalRowCount,
                          displayRowCount, rowHeight);

   -- sort the table by the configured column
   table.sort(UDKP_Snapshots, GRaids:GetSortComparator())

   for line = 1, displayRowCount do
      index = offset + line;
      local buttonName = "RaidEntry" .. line;
      button = getglobal(buttonName);
--       GUtil:Print("Fetching button [name=RaidEntry" .. line .. "].");

      if (button ~= nil) then
--          GUtil:Print("Found button.");
         button.entryIndex = index;

         local snapInfo = UDKP_Snapshots[index];
         if (snapInfo ~= nil) then
            getglobal(buttonName .. "Name"):SetText(snapInfo["event"]);
            getglobal(buttonName .. "Zone"):SetText(snapInfo["zone"]);
            getglobal(buttonName .. "When"):SetText(snapInfo["time"]);
            getglobal(buttonName .. "DKP"):SetText(snapInfo["dkp"]);
            local playerCount = table.getn(snapInfo["players"]);
            getglobal(buttonName .. "Players"):SetText(playerCount);
            local lootCount = table.getn(snapInfo["loot"]);
            getglobal(buttonName .. "Loot"):SetText(lootCount);
         end

         if (GuildomaticRaidsTabFrameScrollBar.selectedEntry == index) then
            selectedSnap = snapInfo
            selectedLoot = nil
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

function GRaids:UpdateSnapDetail ()
   -- deal gracefully if there's no selected snapshot record
   if (selectedSnap == nil) then
      return
   end

   -- set the snapshot detail at top of detail sub-frame
   GuildomaticSnapDetailFrameSnapName:SetText(selectedSnap["event"])
   GuildomaticSnapDetailFrameSnapWhen:SetText(selectedSnap["time"])
   GuildomaticSnapDetailFrameSnapDKP:SetText(selectedSnap["dkp"])

   -- and refresh the loot and player displays for the selected snapshot
   GRaids:UpdateDetailLootScrollBar()
   GRaids:UpdateDetailPlayerScrollBar()
end
