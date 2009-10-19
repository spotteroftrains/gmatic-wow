-- utility functions
GUtil = {}

local DEBUG = false

function GUtil:Blank (str)
   return ((not str) or (string.len(str) == 0))
end

function GUtil:Capitalize (name)
    if (not name) then
        return nil;
    end

    if (strlen(name) == 1) then
        return string.upper(name);
    end

    return (string.upper(string.sub(name, 1, 1)) .. 
            string.lower(string.sub(name, 2)));
end

function GUtil:Debug (msg)
   if DEBUG then
      DEFAULT_CHAT_FRAME:AddMessage("GDB: " .. msg, 1, 1, 0)
   end
end

function GUtil:FixZero (num)
    if (num < 10) then
        return "0" .. num
    else
        return num
    end
end

function GUtil:GetDateTime ()
    local t = date("*t")
    local hours, mins = GetGameTime() 
    return GUtil:FixZero(t.month) .. "/" .. GUtil:FixZero(t.day) .. "/" .. strsub(t.year, 3) .. " " .. GUtil:FixZero(hours) .. ":" .. GUtil:FixZero(mins) .. ":" .. GUtil:FixZero(t.sec)
end

function GUtil:ParseCommands (cmd)
   local commands = {};
   string.gsub(cmd, "%S+", function(word) table.insert(commands, word) end);
   return commands
end

function GUtil:Print (msg)
    DEFAULT_CHAT_FRAME:AddMessage("Guildomatic: " .. msg, 1, 1, 0)
end

function GUtil:PrintError (msg)
    DEFAULT_CHAT_FRAME:AddMessage(RED_FONT_COLOR_CODE .. 
                                  "Guildomatic: [ERROR] " .. 
                                  msg .. NORMAL_FONT_COLOR_CODE, 1, 1, 0);
end

-- function GUtil:ReverseTable (tab)
--    local newTab = {}
--    for key, value in pairs(tab) do
--       tinsert(newTab, 1, value)
--    end
--    newTab
-- end

function GUtil:ReverseComparator (fun)
   return function (a, b) c = a; a = b; b = c; return fun(a, b); end
end

function GUtil:SendChatMessage (to, msg)
    SendChatMessage("Guildomatic: " .. msg, "WHISPER", nil, to)
end

-- remove trailing and leading whitespace from string.
-- http://en.wikipedia.org/wiki/Trim_(8programming)
function GUtil:trim (s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function GUtil:UpdateSortDirection (sortDirs, curSortType, newSortType)
   -- make sure to initialize sort direction for known sort types if
   -- not yet set
   if (not sortDirs[curSortType]) then
      sortDirs[curSortType] = "asc"
   end
   if (not sortDirs[newSortType]) then
      sortDirs[newSortType] = "asc"
   end

   -- if user clicked on the current sort column, reverse sort direction
   if (curSortType == newSortType) then
      if (sortDirs[newSortType] == "asc") then
         sortDirs[newSortType] = "desc"
      else
         sortDirs[newSortType] = "asc"
      end
   end

   return sortDirs[newSortType]
end
