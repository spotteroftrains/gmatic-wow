local Super_ChatFrame_OnEvent;

Guildomatic = {}

local _ENV = getfenv(0)
_ENV["GUILDOMATIC"] = Guildomatic

Guildomatic.Classes = {
   "Death Knight",
   "Druid", 
   "Hunter", 
   "Mage", 
   "Paladin", 
   "Priest", 
   "Rogue", 
   "Shaman", 
   "Warlock", 
   "Warrior" }

Guildomatic.PanelFrames = {
   "GuildomaticRosterTabFrame",
   "GuildomaticRaidsTabFrame",
   "GuildomaticAuctionsTabFrame",
   "GuildomaticDKPTabFrame" }

GM_Config = {}

UDKP_Auctions = {}
UDKP_Calendar_Events = {}
UDKP_Events = {}
UDKP_GuildRoster = {}
UDKP_Players = {}
UDKP_Snapshots = {}

Guildomatic_Submodules = { 
    'GAuctions', 'GConfig', 'GQueue', 'GDKP', 'GRaids', 'GRoster' }

Guildomatic.version = GetAddOnMetadata("Guildomatic", "Version")
Guildomatic.versionstring = 
   "Guildomatic v" .. GetAddOnMetadata("Guildomatic", "Version")

function Guildomatic:Command (args)
   GUtil:Debug("Command [args=" .. args .. "].")

   local _, _, cmd, params = string.find(args, "([^%s]+) ?(.*)")

   if (cmd == "window") then
      Guildomatic:ToggleWindow();

   elseif (cmd == "auction") then
      GAuctions:Command(params);

   elseif (cmd == "cal") then
      GCalendar:Command(params);

   elseif (cmd == "config") then
      GConfig:Show();

   elseif (cmd == "dkp") then
      GDKP:Command(params);

   elseif (cmd == "queue") then
      GQueue:Command(params);

   elseif (cmd == "snapshot" or cmd == "raid") then
      GRaids:Command(params);

   elseif (cmd == "roster") then
      GRoster:Command(params);

   elseif (cmd == "version") then
      GUtil:Print(Guildomatic.versionstring)

   else
      Guildomatic:PrintHelp();
   end
end

function Guildomatic:HideMinimapIcon ()
   GM_Config["MinimapVisible"] = false
   GuildomaticMinimap:Hide()
end

function Guildomatic:OnHide ()
   GM_Config["WindowVisible"] = false
end

function Guildomatic:OnLoad ()
   SlashCmdList["GMATIC"] = function (msg) Guildomatic:Command(msg) end
   SLASH_GMATIC1 = "/gt";
   SLASH_GMATIC2 = "/gmatic";

   this:RegisterEvent("ADDON_LOADED");
   this:RegisterEvent("CHAT_MSG_CHANNEL_JOIN");
   this:RegisterEvent("CHAT_MSG_LOOT");
   this:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
   this:RegisterEvent("PARTY_MEMBERS_CHANGED");
   this:RegisterEvent("PLAYER_ENTERING_WORLD");
   this:RegisterEvent("RAID_ROSTER_UPDATE");
   this:RegisterEvent("VARIABLES_LOADED");

   this:RegisterForDrag("LeftButton");
   
   ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", 
                                   function (...) return Guildomatic:OnLoot(...) end)
   ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER",
                                   function (...) return Guildomatic:OnWhisper(...) end)
   ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", 
                                   function (...) return Guildomatic:OnWhisperInform(...) end)
   ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_JOIN", 
                                   function (...) return GQueue:OnChannelJoin(...) end)
   
   -- set up our tabs    
   PanelTemplates_SetNumTabs(this, #self.PanelFrames)

   GUtil:Print("Module loaded. Type '/gt' for help.")
end

function Guildomatic:OnEvent (event)
--    if (event ~= nil) then
--      GUtil:Debug("Guildomatic:OnEvent [event=" .. event .. "]");
--    else
--      GUtil:Debug("Guildomatic:OnEvent.");
--    end

    if (event == "RAID_ROSTER_UPDATE") then
       GQueue:OnRaidRosterUpdate()

    elseif (event == "PARTY_MEMBERS_CHANGED") then
       GCalendar:OnPartyMembersChanged()

   elseif (event == "ADDON_LOADED") then
      -- for some reason we are seeing three ADDON_LOADED events in
      -- rapid succession on login, with the first returning nil for
      -- IsInGuild().  not harmful but who knows what the story is.
      if (IsInGuild() and GetNumGuildMembers() == 0) then
         -- request a guild roster info update immediately so that we're
         -- likely to have the info if/when record button is pressed
         GuildRoster()
      end

   elseif (event == "VARIABLES_LOADED") then
      -- make sure all config settings are initialized with defaults
      -- if not already set
      Guildomatic:PrepareConfig("AuctionRoundTime", 25)
      Guildomatic:PrepareConfig("AuctionRounds", 3)
      Guildomatic:PrepareConfig("AuctionRunning", 0)
      Guildomatic:PrepareConfig("DKP_Lookups", true)
      Guildomatic:PrepareConfig("DKP_ShowZero", true)
      Guildomatic:PrepareConfig("IgnoredLoot", {})
      Guildomatic:PrepareConfig("LootMinQuality", 4)
      Guildomatic:PrepareConfig("MinimapPos", nil)
      Guildomatic:PrepareConfig("MinimapVisible", true)
      Guildomatic:PrepareConfig("QueueFrequency", 5)
      Guildomatic:PrepareConfig("QueueChannel", "YourChannel")
      Guildomatic:PrepareConfig("Queue_Enabled", 0)
      Guildomatic:PrepareConfig("RosterSnapAt", nil)
      Guildomatic:PrepareConfig("SelectedTab", 1)
      Guildomatic:PrepareConfig("WindowVisible", true)

      -- set up the minimap icon
      Mini:Setup()

      -- let all sub-modules know we've now got our variable data
      for k, v in pairs(Guildomatic_Submodules) do
         getglobal(v):OnVariablesLoaded();
      end

      -- show the current panel
      Guildomatic:ShowPanel(GM_Config["SelectedTab"])

      -- show the window based on configured settings
      if (GM_Config["WindowVisible"] == true) then
         GuildomaticFrame:Show();

      else
         GuildomaticFrame:Hide();
      end

   elseif (event == "COMBAT_LOG_EVENT_UNFILTERED") then
      local event_type = arg2
      
      -- check for boss death
      if (event_type == "UNIT_DIED") then
         local killed = arg7
         for k, v in pairs(UDKP_Events) do
            if (killed == v["name"]) then
               GRaids:TakeSnapshot(v["name"], v["dkp"])
               break
            end
         end
      end

   elseif (event == "PLAYER_ENTERING_WORLD") then
      -- check to see if they're entering an instance
      local posX, posY = GetPlayerMapPosition("player");
      if (posX == 0 and posY == 0 and UDKP_Snapshots) then
         GUtil:Print("Reminder: when entering an instance you may want " ..
                     "to clear old snapshots.");
      end
   end
end

function Guildomatic:OnLoot (...)
   if (GRaids) then
      return GRaids:RecordLoot(...);
   end

   return false, ...;
end

function Guildomatic:OnShow ()
   GM_Config["WindowVisible"] = true
end

function Guildomatic_OnUpdate (elapsed)
   if (GAuctions and GQueue) then
      GAuctions:OnUpdate(elapsed)
      GQueue:OnUpdate(elapsed)
   end
end

function Guildomatic:OnWhisper (self, event, ...)
   local commands = {};

   local msg = select(1, ...);
   local param = select(2, ...); 

   string.gsub(msg, "%S+", function(word) table.insert(commands, word) end);

   local cmd, requestor = commands[1], param;

   if (not cmd or strlen(cmd) == 0) then
      cmd = msg;
   end

   -- make sure our submodules are actually present and loaded.  it
   -- appears other modules or users may sometimes reload our module
   -- and this handler could get called when some of our windows
   -- haven't yet loaded and so their corresponding .lua files
   local handled = false

   if (GAuctions and GDKP and GQueue) then
      handled = GAuctions:OnWhisper(msg, param, cmd, requestor, commands)
      if (not handled) then
         handled = GDKP:OnWhisper(msg, param, cmd, requestor, commands)
         if (not handled) then
            handled = GQueue:OnWhisper(msg, param, cmd, requestor, commands)
         end
      end
   end

   if (handled) then
      return true, ...;

   else
      return false, ...;
   end
end

function Guildomatic:OnWhisperInform (self, event, ...)
   -- catch and dispose of Guildomatic-specific outgoing whispers so
   -- that the user doesn't see a bunch of verbose messages about
   -- stuff they already know

   local msg = select(1, ...);
   local iStart, _ = string.find(msg, "^Guildomatic:");

   if (iStart) then
      return true;

   else
      return false, ...;
   end
end

function Guildomatic:PrepareConfig (field, value)
   local curValue = GM_Config[field]
   if (curValue == nil) then
      GM_Config[field] = value
   end
end

function Guildomatic:PrintHelp ()
   GUtil:Print("Module Help:");
   Guildomatic:PrintHelpLine("auction", "[help for auction]")
   Guildomatic:PrintHelpLine("cal", "[help for calendar events]")
   Guildomatic:PrintHelpLine("config", "[show module config window]")
   Guildomatic:PrintHelpLine("dkp", "<name/class/all/raid> [check dkp]")
   Guildomatic:PrintHelpLine("dkp", "<on/off> [enable/disable dkp lookups]")
   Guildomatic:PrintHelpLine("queue", "[help menu for queue]")
   Guildomatic:PrintHelpLine("roster", "[record the guild roster]")
   Guildomatic:PrintHelpLine("snapshot", "[help for snapshot]")
   Guildomatic:PrintHelpLine("snapshot ignore",
                             "[help for snapshot ignored items]")
   Guildomatic:PrintHelpLine("version", "[show module version]")
   Guildomatic:PrintHelpLine("window", "[toggle main window interface]")
end

function Guildomatic:PrintHelpLine (command, explain)
   GUtil:Print(HIGHLIGHT_FONT_COLOR_CODE .. "/gt " .. command .. 
               NORMAL_FONT_COLOR_CODE .. " " .. explain)
end

function Guildomatic:GetCurrentPanel ()
   if (GM_Config and GM_Config["SelectedTab"]) then
      return GM_Config["SelectedTab"]

   else
      -- deal gracefully with early module load state where we may not
      -- have yet populated our config
      return -1
   end
end

function Guildomatic:SetCurrentPanel (panelIndex)
   if (GM_Config) then
      GM_Config["SelectedTab"] = panelIndex
   end
end

function Guildomatic:ShowMinimapIcon ()
   GM_Config["MinimapVisible"] = true
   GuildomaticMinimap:Show()
end

function Guildomatic:ShowPanel (panelIndex)
   -- hide the current frame
   local curPanelIndex = Guildomatic:GetCurrentPanel()
   if (curPanelIndex ~= -1) then
      getglobal(Guildomatic.PanelFrames[curPanelIndex]):Hide()
   end

    -- show the specified panel
   Guildomatic:SetCurrentPanel(panelIndex)
   getglobal(Guildomatic.PanelFrames[panelIndex]):Show()

    -- and update the tab to reflect the new panel
    PanelTemplates_SetTab(GuildomaticFrame, panelIndex)
end

function Guildomatic:ToggleWindow ()
   if GuildomaticFrame:IsVisible() then
      GuildomaticFrame:Hide();

   else
      GuildomaticFrame:Show();
   end
end

-- Minimap routines.  we tried to stick these in their own file but
-- couldn't get it working for some reason, need to revisit later.

Mini = {}

-- Much of this is adapted/hacked-up from LibDBIcon-1.0 found in the
-- Omen source.

local minimapShapes = {
	["ROUND"] = {true, true, true, true},
	["SQUARE"] = {false, false, false, false},
	["CORNER-TOPLEFT"] = {true, false, false, false},
	["CORNER-TOPRIGHT"] = {false, false, true, false},
	["CORNER-BOTTOMLEFT"] = {false, true, false, false},
	["CORNER-BOTTOMRIGHT"] = {false, false, false, true},
	["SIDE-LEFT"] = {true, true, false, false},
	["SIDE-RIGHT"] = {false, false, true, true},
	["SIDE-TOP"] = {true, false, true, false},
	["SIDE-BOTTOM"] = {false, true, false, true},
	["TRICORNER-TOPLEFT"] = {true, true, true, false},
	["TRICORNER-TOPRIGHT"] = {true, false, true, true},
	["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
	["TRICORNER-BOTTOMRIGHT"] = {false, true, true, true},
}

function Mini:Setup ()
   local button = CreateFrame("Button", "GuildomaticMinimap", Minimap)

   button:SetFrameStrata("MEDIUM")
   button:SetWidth(31); button:SetHeight(31)
   button:SetFrameLevel(8)
   button:RegisterForClicks("anyUp")
   button:RegisterForDrag("LeftButton")
   button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
   local overlay = button:CreateTexture(nil, "OVERLAY")
   overlay:SetWidth(53); overlay:SetHeight(53)
   overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
   overlay:SetPoint("TOPLEFT")
   local icon = button:CreateTexture(nil, "BACKGROUND")
   icon:SetWidth(20); icon:SetHeight(20)
   icon:SetTexture("Interface\\AddOns\\Guildomatic\\Textures\\MiniLogo")
   icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
   icon:SetPoint("TOPLEFT", 7, -5)
   button.icon = icon

   button.total = 0
   button:SetScript("OnEnter", onMiniEnter)
   button:SetScript("OnLeave", onMiniLeave)
   button:SetScript("OnClick", onMiniClick)
   button:SetScript("OnDragStart", onMiniDragStart)
   button:SetScript("OnDragStop", onMiniDragStop)
   button:SetScript("OnMouseDown", onMiniMouseDown)
   button:SetScript("OnMouseUp", onMiniMouseUp)
   button:SetScript("OnUpdate", onMiniUpdateAndKill)

   button.minimapPos = GM_Config["MinimapPos"]
   self:UpdatePosition(button)
end

function onMiniClick (self, button)
   if (button == "RightButton") then
      GConfig:Show()

   else
      Guildomatic:ToggleWindow()
   end
end

function onMiniDragStart (self)
   self:LockHighlight()
   self.icon:SetTexCoord(0, 1, 0, 1)
   self:SetScript("OnUpdate", onMiniUpdate)
   GameTooltip:Hide()
end

function onMiniDragStop (self)
   self:SetScript("OnUpdate", nil)
   self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
   self:UnlockHighlight()
end

local function getAnchors(frame)
	local x,y = frame:GetCenter()
	if not x or not y then return "TOPLEFT", "BOTTOMLEFT" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

function onMiniEnter (self)
   GameTooltip:SetOwner(self, "ANCHOR_NONE")
   GameTooltip:SetPoint(getAnchors(self))
   onMiniTooltipShow(GameTooltip)
end

function onMiniLeave (self)
--    local o = self.dataObject
--    if MouseIsOver(GameTooltip) and (o.tooltiptext or o.OnTooltipShow) then return end	
--    if o.tooltiptext or o.OnTooltipShow then
--       GT_OnLeave(GameTooltip)
--    end
--    if o.OnLeave then o.OnLeave(self) end
end

function onMiniMouseDown (self) self.icon:SetTexCoord(0, 1, 0, 1) end

function onMiniMouseUp (self) self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95) end

function onMiniTooltipShow (tt)
   tt:AddLine("Guildomatic")
   tt:AddLine("|cffffff00" .. "Click|r to toggle the Guildomatic window")
   tt:AddLine("|cffffff00" .. "Right-click|r to open the config window")
end

function onMiniUpdate (self)
   local mx, my = Minimap:GetCenter()
   local px, py = GetCursorPosition()
   local scale = Minimap:GetEffectiveScale()
   px, py = px / scale, py / scale
   self.minimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
   Mini:UpdatePosition(self)
end

function onMiniUpdateAndKill (self, elapsed)
   self.total = self.total + elapsed
   if self.total <= 15 then 
      Mini:UpdatePosition(self)
      self:SetScript("OnUpdate", nil)
   end
end

function Mini:UpdatePosition (button)
   local radius = 80
   local rounding = 10
   local position = button.minimapPos or random(0, 360)
   button.minimapPos = position
   button.radius = radius

   local angle = math.rad(position)
   local x, y, q = math.cos(angle), math.sin(angle), 1
   if x < 0 then q = q + 1 end
   if y > 0 then q = q + 2 end
   local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
   local quadTable = minimapShapes[minimapShape]
   if quadTable[q] then
      x, y = x*radius, y*radius
   else
      local diagRadius = math.sqrt(2*(radius)^2)-rounding
      x = math.max(-radius, math.min(x*diagRadius, radius))
      y = math.max(-radius, math.min(y*diagRadius, radius))
   end
   button:SetPoint("CENTER", Minimap, "CENTER", x, y)

   if (GM_Config["MinimapVisible"]) then
      button:Show()
   else
      button:Hide()
   end

   -- remember the minimap icon position
   GM_Config["MinimapPos"] = button.minimapPos
end
