Auctions = {}

local elapsedTimer = 0
local sortDirs = {}

function Auctions:AcceptBid (bidder, bid)
   if (not bid) then
      GUtil:SendChatMessage(bidder, "Bid must be submitted as " ..
                            "'<bid amount>', example: /w " .. 
                            UnitName("player") .. " 100");
      return;
   end

   local auctions = Auctions:GetAuctionsByStartTime()
   local auction = auctions[1]

--    GUtil:Debug("AcceptBid, auctions by start time:")
--    for k, v in pairs(auctions) do
--       GUtil:Debug(k .. ". " .. v["item"])
--    end

   --local requestor_dkp = 0;
   --for k, v in pairs(UDKP_Players) do
   --if (v["name"] == bidder) then
   --requestor_dkp = tonumber(v["dkp"]);
   --end
   --end

   -- reject their bid if they have no DKP
   --if (requestor_dkp == 0) then
   --GUtil:SendChatMessage(bidder, "You have no DKP to bid.");
   --return;
   --end

   -- make sure we're having an auction
   if (not auction or (auction and auction["start"] == -1)) then
      GUtil:SendChatMessage(bidder, "No active auction for bidding.");
      -- make sure it's a valid bid
      --elseif (not bid or bid > requestor_dkp) then
      --GUtil:SendChatMessage(bidder, "Illegal bid. Bid must be a number less than your current DKP amount");
      -- it's a valid bid, let's do further checks
      return
   end

   -- require minimum bid amount
   if (bid <= 0) then
      GUtil:SendChatMessage(bidder, "Bid must be greater than zero.")
      return
   end

   -- check and make sure they were in previous rounds and bidding higher
   local acceptbid = 0;

   for k, bids in pairs(auction["bids"]) do
      -- make sure they were in previous round and bidding higher
      if (bids["name"] == bidder and 
          bids["round"] == (auction["round"] - 1)) then
         if (bid <= auction["highbid"]) then
            GUtil:SendChatMessage(bidder, "You must bid higher than " ..
                                  "previous round's high bid of " .. 
                                  auction["highbid"] .. ".");
            return;
         end

         acceptbid = 1;
         -- maybe we're just updating their current round bid

      elseif (bids["name"] == bidder and 
              bids["round"] == auction["round"]) then
         bids["bid"] = bid;
         GUtil:Print('Bid updated to ' .. bid .. ' from ' .. bidder .. '.');
         GUtil:SendChatMessage(bidder, "Bid of " .. bid .. " accepted.");
         return;
      end
   end

   if (acceptbid == 1 or auction["round"] == 0) then
      GUtil:Print('Bid of ' .. bid .. ' from ' .. bidder .. '.');
      GUtil:SendChatMessage(bidder, "Bid of " .. bid .. " accepted.");

      tinsert(auction["bids"], 
              { ["name"] = bidder, 
                ["bid"] = bid, 
                ["round"] = auction["round"] });

   else
      GUtil:SendChatMessage(bidder, "Bid not accepted. You were not a " ..
                            "bidder in the previous round.");
   end
end
 
function Auctions:Command (cmd)
   local commands = GUtil:ParseCommands(cmd)
   local firstWord = commands[1];

   GUtil:Debug("Auctions:Command [cmd=" .. cmd .. "].")

   if GUtil:Blank(cmd) then
      Auctions:PrintHelp()

   elseif (cmd == "clear") then
      Auctions:DoClearAllAuctions()

   elseif (firstWord == "config") then
      Auctions:DoConfig(commands)

   elseif (cmd == "list") then
      Auctions:DoListAuctions()

   elseif (firstWord == "remove") then
      Auctions:DoRemoveAuction(commands)

   elseif (cmd == "stop") then
      Auctions:DoStopAuction()

   else
      Auctions:DoStartAuction(cmd)
   end
end

function Auctions:DoClearAllAuctions () 
   UDKP_Auctions = { };
   GUtil:Print("Cleared all auctions.")
   Auctions:UpdateScrollBar()
end

function Auctions:DoConfig (commands)
   if (commands[2] and commands[3]) then
      local numRounds = tonumber(commands[2]);
      local roundLength = tonumber(commands[3]);

      if (numRounds and roundLength) then
         GM_Config["AuctionRounds"] = numRounds;
         GM_Config["AuctionRoundTime"] = roundLength;
         GUtil:Print("Auctions now configured for " .. 
                     GM_Config["AuctionRounds"] .. " rounds of " .. 
                     GM_Config["AuctionRoundTime"] .. " seconds.")
         return;
      end
   end

   GUtil:PrintError("Usage: /gt auction config <# of rounds> " ..
                    "<round length in seconds> [configure auctions].");
end

function Auctions:DoListAuctions ()
   local num = 0;
   if (UDKP_Auctions) then
      for k, v in pairs(UDKP_Auctions) do
         local auction_time;

         if (v["utc_time"]) then
            auction_time = date("%x %X", v["utc_time"]);
         else
            auction_time = v["end"];
         end

         GUtil:Print(k .. ". " .. 
                     auction_time .. " - " .. 
                     v["item"] .. " <" .. 
                     v["winner"] .. "/" .. 
                     v["highbid"] .. ">.");
         num = num + 1;
      end
   end

   if (num == 0) then
      GUtil:Print("No auctions.");
   end
end

function Auctions:DoRemoveAuction (commands)
   if (commands[2]) then
      local snum = tonumber(commands[2]);

      if (snum) then
         for k, v in pairs(UDKP_Auctions) do
            if (k == snum) then
               tremove(UDKP_Auctions, snum);
               GUtil:Print("Removed auction entry " .. snum .. ".");
               return;
            end
         end
         GUtil:Print("Auction entry " .. snum .. " not found.");
      end

   else
      GUtil:PrintError("Usage: /gt auction remove <auction #>");
   end
end

function Auctions:DoStartAuction (args)
   if (GM_Config["AuctionRunning"] == 1) then
      GUtil:PrintError("There is an auction already running.");
      return
   end

   local _, _, sItem = string.find(args, "^(.+)");
   sItem = GUtil:trim(sItem)

   Auctions:Print("Auctioning " .. sItem .. ". " .. 
                  GM_Config["AuctionRounds"] .. " rounds of bidding. " .. 
                  GM_Config["AuctionRoundTime"] .. " seconds in each round.")

   Auctions:Print("Whisper " .. UnitName("player") .. 
               " to bid. Example: '/w " .. UnitName("player") .. " 100'.")

   Auctions:Print("Now taking bids.")

   -- create auction and provide extra 5 seconds for people to get started
   tinsert(UDKP_Auctions, 1, {
              ["item"] = sItem,
              ["start"] = GetTime() + 3,
              ["end"] = "",
              ["round"] = 0,
              ["timer"] = 0,
              ["highbid"] = 0,
              ["numhighbids"] = 0,
              ["winner"] = "none",
              ["winners"] = "none",
              ["bids"] = { }
           });

   GM_Config["AuctionRunning"] = 1
end

function Auctions:DoStopAuction ()
   if (GM_Config["AuctionRunning"] == 1) then
      GM_Config["AuctionRunning"] = 0

      local auctions = Auctions:GetAuctionsByStartTime()
      auction = auctions[1];

      if (auction and auction["start"] >= 0) then
         auction["round"] = GM_Config["AuctionRounds"];
         auction["start"] = -1;
         Auctions:Print("Auction cancelled.");

         -- actually remove the unfinished auction from the master listxs
         tremove(UDKP_Auctions, auction["base_auction_index"])

         Auctions:UpdateScrollBar();
      end

      GUtil:Print("Auction stopped.");

   else
      GUtil:PrintError("No auction running.");
   end
end

function Auctions:GetAuctionsByStartTime ()
   local auctions = {}
   for key, value in pairs(UDKP_Auctions) do
      value["base_auction_index"] = key
      table.insert(auctions, value)
   end
   table.sort(auctions, function (a, b) return a["start"] > b["start"] end);
   return auctions
end

function Auctions:GetNumBidders (auction, round)
   local numBidders = 0;

   for k, bid in pairs(auction["bids"]) do
      if (bid["round"] == round) then
         numBidders = numBidders + 1;
      end
   end

   return numBidders;
end

function Auctions:GetSize ()
    return table.getn(UDKP_Auctions)
end

function Auctions:GetSortComparator ()
   local sortField = GuildomaticAuctionsTabFrame.sortType

   local sfunc = nil
   if (sortField ~= "winner") then
      sfunc = function (a, b)
                if (a[sortField] == b[sortField]) then
                   if (a["winner"] == b["winner"]) then
                      return (a["item"] < b["item"])
                   else
                      return (a["winner"] < b["winner"])
                   end

                else
                   return (a[sortField] < b[sortField])
                end
             end

   else
      sfunc = function (a, b) return a[sortField] < b[sortField] end
   end

   local reverse = (GuildomaticAuctionsTabFrame.sortDir and 
                    GuildomaticAuctionsTabFrame.sortDir == "desc")
   if (reverse) then return GUtil:ReverseComparator(sfunc) else return sfunc end
end

function Auctions:OnAuctionsEntryClick (button)
   GUtil:Debug("Auctions entry clicked [id=" .. this:GetID() .. "].")
   GuildomaticAuctionsTabFrameScrollBar.selectedEntry = 
      getglobal("AuctionsEntry" .. this:GetID()).entryIndex;

   Auctions:UpdateScrollBar();
end

function Auctions:OnClearAllClicked ()
   Auctions:DoClearAllAuctions()
end

function Auctions:OnLoad ()
   GuildomaticAuctionsTabFrame.sortType = "end"
end

function Auctions:OnShow ()    
--    GUtil:Debug("Auctions:OnShow");
end

function Auctions:OnSortColumnClicked (sortType)
   -- allow flipping sort direction or restoring previous direction by column
   GuildomaticAuctionsTabFrame.sortDir =
      GUtil:UpdateSortDirection(sortDirs, GuildomaticAuctionsTabFrame.sortType, 
                                sortType)

   -- note the newly specified sort column
   GuildomaticAuctionsTabFrame.sortType = sortType   

   -- refresh the view
   Auctions:UpdateScrollBar();
end

-- this is only used for updating the auction
function Auctions:OnUpdate (elapsed)
   -- TODO: wow, this is a lot of conditional action.  break into methods.
   elapsedTimer = elapsedTimer + elapsed

   if (elapsedTimer <= 0.1) then
      -- nothing to do if no time has elapsed
      return
   end

   if (GM_Config["AuctionRunning"] == 0) then
      -- nothing to do if no auction is running
      return
   end

   local auctions = Auctions:GetAuctionsByStartTime()
   auction = auctions[1];

   if not auction then
      return
   end

   local item, start, round, highbid = 
      auction["item"], auction["start"], auction["round"], 
      auction["highbid"];

   local now = GetTime()

   if (auction["start"] >= 0 and round < GM_Config["AuctionRounds"]) then
      -- auction is now over, determine winner
      local roundSecs = (GM_Config["AuctionRounds"] * 
                         GM_Config["AuctionRoundTime"])
      if (now > (start + roundSecs)) then
         Auctions:UpdateAuctionWinner(auction, round);

         -- if we only have 1 bidder in the last round, use the
         -- previous round's high bid, but only if this was either the
         -- first round, or the previous round wasn't a tie
         local lastWinner = auction["winner"];
         if ((Auctions:GetNumBidders(auction, round) == 1) and 
             (lastWinner == auction["winner"]) and
             ((round > 0) and (not Auctions:RoundWasTie(auction, round - 1)))) then
            Auctions:UpdateAuctionWinner(auction, round - 1);
         end

         -- end the auction
         auction["round"] = GM_Config["AuctionRounds"];
         auction["start"] = -1;

         if (auction["highbid"] > 0) then
            -- check if there was a tie
            if (auction["numhighbids"] > 1) then
               Auctions:Print("Auction tied. " .. 
                              auction["numhighbids"] .. " bids for " .. 
                              auction["highbid"] .. " DKP from " .. 
                              auction["winners"] .. ".")

            else
               Auctions:Print("Auction over for " .. 
                              item .. ". " .. auction["winner"] .. 
                              " wins for " .. auction["highbid"] .. 
                              " DKP.");
            end

            -- note the ending time of the auction
            auction["end"] = GUtil:GetDateTime();
            auction["utc_time"] = time();

         else
            Auctions:Print("Auction over for " .. item .. ". No bidders.");

            -- no bidders, so just remove it from the table
            tremove(UDKP_Auctions, auction["base_auction_index"])
         end

         GM_Config["AuctionRunning"] = 0

         Auctions:UpdateScrollBar()

      elseif (now > (start + (round+1) * GM_Config["AuctionRoundTime"])) then
         -- the current, and not-final, round of bidding is over
         local numBidders = Auctions:GetNumBidders(auction, round);
         if (numBidders > 1) then
            Auctions:UpdateAuctionWinner(auction, round);
            Auctions:Print("Auction round " .. 
                           round + 1 .. " over for " .. 
                           item .. ". " .. 
                           auction["numhighbids"] .. 
                           " high bid(s) of " .. 
                           auction["highbid"] .. ".");

            auction["round"] = round + 1;
            if (auction["round"] == (GM_Config["AuctionRounds"] - 1)) then
               Auctions:Print("Last round of bidding begins.");

            else
               Auctions:Print("Next round of bidding begins.");
            end

         else
            auction["start"] = 0;
         end

      elseif (now > (start + (GM_Config["AuctionRoundTime"] * (round+1) - 10))) then
         -- handle displaying final-secs countdown to the group

         -- TODO: there has to be a floor() or trunc() we can use
         -- instead of this?
         local _, _, timer = string.find(start + GM_Config["AuctionRoundTime"]*(round+1) - now + 1, "^(%d+)");

         if (auction["timer"] ~= timer) then
            auction["timer"] = timer;
            Auctions:Print(timer .. " seconds left.");
         end
      end
   end

   elapsedTimer = elapsedTimer - 0.1
end

function Auctions:OnVariablesLoaded ()
   -- always start out with no running auction
   GM_Config["AuctionRunning"] = 0
   elapsedTimer = 0
end

function Auctions:OnWhisper (msg, param, cmd, requestor, commands)
   if (GM_Config["AuctionRunning"] == 1 and string.lower(cmd) == "bid") then
      Auctions:AcceptBid(requestor, tonumber(commands[2]));
      return true

   elseif (GM_Config["AuctionRunning"] == 1 and 
           tonumber(cmd) and 
           (not commands[2])) then
      Auctions:AcceptBid(requestor, tonumber(cmd));
      return true
   end

   return false
end

function Auctions:Print (msg)
   if (GetNumRaidMembers() > 0)  then
      SendChatMessage(msg, "RAID");

   elseif (GetNumPartyMembers() > 0) then
      SendChatMessage(msg, "PARTY");

   else
      SendChatMessage(msg, "SAY");
   end
end

function Auctions:PrintHelp ()
   Guildomatic:PrintHelpLine("auction", 
                             "<item> [start an auction for the item]")
   Guildomatic:PrintHelpLine("auction clear", "[deletes all auctions]")
   Guildomatic:PrintHelpLine("auction config",
                             "<# of rounds> <round length in seconds> " ..
                             "[configure auctions]")
   Guildomatic:PrintHelpLine("auction list", "[list auctions]")
   Guildomatic:PrintHelpLine("auction remove", 
                             "<auction #> [remove an auction]")
   Guildomatic:PrintHelpLine("auction stop", "[stop an auction]")

   GUtil:Print("Auctions currently configured for " .. 
               GM_Config["AuctionRounds"] .. " rounds of " ..
               GM_Config["AuctionRoundTime"] .. " seconds.")
end

function Auctions:RoundWasTie (auction, round)
   local maxBid = 0;
   local bidCount = {};

   -- gather a count of number of bids at each bid price for the
   -- specified round
   for k, bid in pairs(auction["bids"]) do
      if (bid["round"] == round) then
         -- update the max bid overall for this round
         if (bid["bid"] > maxBid) then
            maxBid = bid["bid"]
         end

         -- update number of bidders for this bid amount
         if (not bidCount[bid["bid"]]) then
            bidCount[bid["bid"]] = 0
         end

         bidCount[bid["bid"]] = bidCount[bid["bid"]] + 1;
      end
   end

   local maxBidderCount = (bidCount[maxBid] or 0);
--    GUtil:Debug("Auctions:RoundWasTie [maxBid=" .. maxBid .. ", maxBidderCount=" .. maxBidderCount .. "].");

   return (maxBidderCount > 1);
end

function Auctions:SetHeaderWidth (frame, width)
   frame:SetWidth(width);
   getglobal(frame:GetName().."Middle"):SetWidth(width - 9);
end

function Auctions:UpdateAuctionWinner (auction, round)
   local highbid, numhighbids, name, winners = 0, 0, "", "";

   for k, bid in pairs(auction["bids"]) do
      if (bid["bid"] > highbid and bid["round"] <= round) then
         highbid = bid["bid"];
         name = bid["name"];
         numhighbids = 1;
         winners = name;

      elseif (bid["bid"] == highbid) then
         numhighbids = numhighbids + 1;
         winners = winners .. ", " .. bid["name"];
      end
   end

   auction["highbid"] = highbid;
   auction["numhighbids"] = numhighbids;
   auction["winner"] = name;
   auction["winners"] = winners;
end

function Auctions:UpdateScrollBar ()
   local offset = 
      FauxScrollFrame_GetOffset(GuildomaticAuctionsTabFrameScrollBar)
   local totalRowCount = Auctions:GetSize();
   local rowHeight = 16
   local displayRowCount = 20

   -- GUtil:Debug("Updating scrollbar [offset=" .. offset .. "].")
   FauxScrollFrame_Update(GuildomaticAuctionsTabFrameScrollBar, totalRowCount,
                          displayRowCount, rowHeight);

   -- sort the table by name
   table.sort(UDKP_Auctions, Auctions:GetSortComparator())

   for line = 1, displayRowCount do
      index = offset + line;
      local buttonName = "AuctionsEntry" .. line;
      button = getglobal(buttonName);
--       GUtil:Debug("Fetching button [name=AuctionsEntry" .. line .. "].");

      if (button ~= nil) then
--          GUtil:Debug("Found button.");
         button.entryIndex = index;

         local auctionInfo = UDKP_Auctions[index];
         if (auctionInfo ~= nil) then
            getglobal(buttonName .. "Date"):SetText(auctionInfo["end"]);
            getglobal(buttonName .. "Item"):SetText(auctionInfo["item"]);
            getglobal(buttonName .. "Winner"):SetText(auctionInfo["winner"]);
            getglobal(buttonName .. "DKP"):SetText(auctionInfo["highbid"]);
         end

         if (GuildomaticAuctionsTabFrameScrollBar.selectedEntry == index) then
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
