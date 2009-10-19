GQueue = {}

local UDKP_DefaultLanguage = GetDefaultLanguage(player);
local UDKP_LastQueuePrintTime = 0;
local UDKP_Queue = {};
local UDKP_QueueWhispers = {};

local elapsedTimer = 0

function GQueue:Command (cmd)
   local commands = GUtil:ParseCommands(cmd)
   local firstWord = commands[1];
   GUtil:Debug("GQueue:Command [cmd=" .. cmd .. "].")

   if GUtil:Blank(cmd) then
      GQueue:PrintHelp()

   elseif (firstWord == "on") then
      GQueue:SetQueueEnabled(true)

   elseif (firstWord == "off") then
      GQueue:SetQueueEnabled(false)

   elseif (firstWord == "config") then
      GQueue:DoConfig(commands)

   elseif (firstWord == "print") then
      GQueue:DoPrintQueue(commands[2])

   elseif (firstWord == "remove") then
      GQueue:DoRemove(commands[2])

   elseif (firstWord == "status") then
      GQueue:DoPrintQueue()

   elseif (firstWord == "clear") then
      GQueue:DoRemove("all")

   elseif (firstWord == "add") then
      local _, _, addParams = string.find(cmd, "^add[%s]+(.*)$");
      GQueue:DoAdd(addParams, commands)
   end
end

function GQueue:DoAdd (addParams, commands)
   -- we have to parse the one-word name and then the potentially
   -- multi-word class separately here, to allow for classes like
   -- "Death Knight"
   local _, _, player, class = string.find(addParams, "^([^%s]+)[%s]+(.*)$");
   player = GUtil:Capitalize(player);

   if (not player or strlen(player) ==0) then
      GUtil:Print("Usage: /gt queue add <player> <class>[add a player to queue]");
      return;
   end

   for k, v in pairs(UDKP_Players) do
      if (v["name"] == player) then
         class = v["class"];
         break;
      end
   end

   if (not class) then
      GUtil:PrintError("Don't know who that is. Please specify class in command: /gt queue add <name> <class>");

   else 
      GQueue:DoAddPlayerToQueue(player, class);
   end
end

function GQueue:DoAddPlayerToQueue (player, class, alt)
   player = GUtil:Capitalize(player);
   class = GUtil:Capitalize(class);
   alt = GUtil:Capitalize(alt);

   for k, v in pairs(UDKP_Queue) do
      if (v["name"] == player) then
         return -1;
      end
   end

   for k, v in pairs(Guildomatic.Classes) do
      if (string.lower(v) == string.lower(class)) then
         local time = time();
         tinsert(UDKP_Queue, { ["name"]=player, ["class"]=v, ["time"]=time, ["alt"]=alt });
         GUtil:Print(player .. " joins " .. v .. " queue.");
         return 0;
      end
   end
   return -2;
end

function GQueue:DoConfig (commands)
   if (commands[2] and commands[3]) then
      local freq = tonumber(commands[3]);
      if (freq) then
         GM_Config["QueueFrequency"] = freq;
         GM_Config["QueueChannel"] = commands[2];

         GUtil:Print("Queue will now print to the '" .. GM_Config["QueueChannel"] .. "' channel every " .. 
                     GM_Config["QueueFrequency"] .. " minutes.");
         return;
      end
   end

   GUtil:Print("Usage: /gt queue config <channel> <# of mins> " ..
               "[ex. /queue config MyQueueChannel 5, this would output queue status/information to " ..
               "'MyQueueChannel' every 5 minutes].");
end

function GQueue:DoPrintQueue (channel, requestor)   
   GQueue:PrintToQueueChannel(channel, requestor, "Queue status");

   local numresults = 0;
   if (UDKP_Queue) then
      table.sort(UDKP_Queue, function(a, b) return a["time"] < b["time"] end);

      for k, class in pairs(Guildomatic.Classes) do
         local list = "";

         for k, player in pairs(UDKP_Queue) do
            local pclass = player["class"];
            if (player["class"] == class) then
               if (not player["alt"]) then
                  list = list .. " " .. player["name"];

               else
                  list = list .. " " .. player["name"] .. "(" .. player["alt"] .. ")";
               end
            end
         end

         if (strlen(list) > 0) then
            GQueue:PrintToQueueChannel(channel, requestor, class .. ":" .. list);
            numresults = numresults + 1;
         end
      end
   end

   if (numresults == 0) then
      GQueue:PrintToQueueChannel(channel, requestor, "Empty queue.");
   end

   GQueue:PrintToQueueChannel(channel, requestor, 
                              "Whisper " .. UnitName("player") .. " 'q join' to join the queue. " ..
                              "'q leave' to leave the queue. 'q status' for the current queue.");
end

function GQueue:DoRemove (player)
    if (not player or strlen(player) == 0) then
        GUtil:Print("Usage: /gt queue remove <player> [removes a player from queue]");
        return -1;
    end

    player = GUtil:Capitalize(player);

    if (player == "All") then
        UDKP_Queue = {};
        GUtil:Print("Queue has been cleared.", 1, 0.2, 0.2);
        return 0;
    end

    for k, v in pairs(UDKP_Queue) do
        if (v["name"] == player) then
            table.remove(UDKP_Queue, k);
            GUtil:Print(player .. " has been removed from the queue.");
            return 0;
        end
    end

    GUtil:PrintError("No such player in queue: " .. player .. ".");
    return -1;
end

function GQueue:OnChannelJoin (msg)
   if (arg9 and arg2 and (GM_Config["Queue_Enabled"] == 1) and 
       (string.lower(arg9) == string.lower(GM_Config["QueueChannel"]))) then
      local player = arg2;
      local channel = arg9;
      local found = 0;

      -- check the raid
      local raiders = GetNumRaidMembers();
      if (raiders > 0) then
         for i = 1, raiders, 1 do
            if (player == UnitName("raid" .. i)) then
               found = 1;
               break;
            end
         end
      end

      -- check the queue
      if (found == 0) then
         for k, v in pairs(UDKP_Queue) do
            if (v["name"] == player) then
               found = 1;
               break;
            end
         end
      end

      -- check and make sure we haven't whispered them in awhile
      if (found == 0) then
         for k, v in pairs(UDKP_QueueWhispers) do
            if (v["name"] == player) then
               if (GetTime() < v["time"] + 60) then
                  found = 1;

               else
                  tremove(UDKP_QueueWhispers, k);
               end
               break;
            end
         end
      end

      -- we're safe to send them a queue whisper
      if (found == 0) then
         GUtil:Print("Sending queue whisper to " .. player);
         GUtil:SendChatMessage(player, "Whisper me for queue, ie. 'q join', 'q leave', 'q status'.");
         tinsert(UDKP_QueueWhispers, {["name"] = player, ["time"] = GetTime()});
         return;
      end
   end
end

function GQueue:OnRaidRosterUpdate ()
   -- if we're in raid and we have a queue going, make sure we remove
   -- players from queue that end up joining the raid
   if (GetNumRaidMembers() > 0 and UDKP_Queue) then
      for k, v in pairs(UDKP_Queue) do
         for i = 1, GetNumRaidMembers(), 1 do
            local player = UnitName("raid" .. i);
            if (player and v["name"] == player) then
               GQueue:DoRemove(player);
            end
         end
      end
   end
end

function GQueue:OnUpdate (elapsed)
   elapsedTimer = elapsedTimer + elapsed

   if (elapsedTimer <= 0.1) then
      -- nothing to do if no time has elapsed
      return
   end

   -- check to see if we need to output our queue status to the channel
   if (UDKP_Queue and 
       GM_Config["QueueFrequency"] and
       (GM_Config["Queue_Enabled"] == 1) and
       GetTime() > (UDKP_LastQueuePrintTime + GM_Config["QueueFrequency"]*60)) then

      -- make sure we have folks in the queue before we go to auto-print
      for k, v in pairs(UDKP_Queue) do
         GQueue:DoPrintQueue("channel");
         break;
      end

      UDKP_LastQueuePrintTime = GetTime();
   end

   elapsedTimer = elapsedTimer - 0.1
end

function GQueue:OnWhisper (msg, param, cmd, requestor, commands)
   if (string.lower(cmd) == "q") then
      if (GM_Config["Queue_Enabled"] == 0) then
         GUtil:SendChatMessage(requestor, "Queue is currently disabled. Maybe someone else is running the queue.");

      elseif (commands[2] == "join") then
         -- we have to parse the parameter here as it could be
         -- multi-word, e.g. "Death Knight"
         local _, _, class = string.find(msg, "^q[%s]+join[%s]+(.*)[%s]*$");

         if (not class) then
            for k, v in pairs(UDKP_Players) do
               if (v["name"] == requestor) then
                  class = v["class"];
                  break;
               end
            end
         end

         if (not class) then
            GUtil:SendChatMessage(requestor, "I don't know what class you are yet. Please specify your class " ..
                                  "when joining queue, ie. /w " .. UnitName("player") .. " q join <class>");

         else
            local result = GQueue:DoAddPlayerToQueue(requestor, class);
            if (result == -1) then
               GUtil:SendChatMessage(requestor, "You're already in the queue.");

            elseif (result == -2) then
               GUtil:SendChatMessage(requestor, class .. " is not a recognized class, ie. Paladin, Warrior, etc.");

            elseif (result == 0) then
               GUtil:SendChatMessage(requestor, "You're now in the " .. class .. " queue.");
            end
         end

      elseif (commands[2] == "leave") then
         local result = GQueue:DoRemove(requestor);
         if (result == -1) then
            GUtil:SendChatMessage(requestor, "You're not in the queue.");

         elseif (result == 0) then
            GUtil:SendChatMessage(requestor, "You've been removed from the queue.");
         end

      elseif (commands[2] == "status") then
         GQueue:DoPrintQueue("whisper", requestor);
      end
      return true;
   end

   return false
end

function GQueue:OnVariablesLoaded ()
   elapsedTimer = 0
end

function GQueue:PrintHelp ()
   Guildomatic:PrintHelpLine("queue <on/off>", "[enables/disables the queue]")
   Guildomatic:PrintHelpLine("queue print <raid/officer/say/party/guild/channel>", "[prints queue to channel, specifying 'channel' will print to the configured channel]")
   Guildomatic:PrintHelpLine("queue add <name> <class>", "[add a player to the queue]")
   Guildomatic:PrintHelpLine("queue remove <name>", "[remove a player from the queue]")
   Guildomatic:PrintHelpLine("queue clear", "[clears the queue]")
   Guildomatic:PrintHelpLine("queue config <channel> <# of mins>", 
                             "[set the channel to which queue messages are outputted and " ..
                                "how often to print queue status]")
   Guildomatic:PrintHelpLine("queue status", "[view queue status]")
end

function GQueue:PrintToQueueChannel (channel, requestor, msg)
    if (not channel) then
        channel = "";

    else
        channel = string.upper(channel);
    end

    if (channel == "PARTY" or channel == "OFFICER" or channel == "SAY" or channel == "RAID" or channel == "GUILD") then
        SendChatMessage(msg, channel, UDKP_DefaultLanguage);

    elseif (channel == "CHANNEL" and GM_Config["QueueChannel"]) then
        SendChatMessage(msg, channel, UDKP_DefaultLanguage, GetChannelName(GM_Config["QueueChannel"]));

    elseif (channel == "WHISPER") then
        GUtil:SendChatMessage(requestor, msg);

    else
        GUtil:Print(msg);
    end
end

function GQueue:SetQueueEnabled (enabled)
   if (enabled) then
      GM_Config["Queue_Enabled"] = 1
      GUtil:Print("Queue is now enabled.")

   else
      GM_Config["Queue_Enabled"] = 0
      GUtil:Print("Queue is now disabled.")
   end
end
