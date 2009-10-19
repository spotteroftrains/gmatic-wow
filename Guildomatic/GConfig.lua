GConfig = {};

-- all very hacky, swiped from observing bits of omen and ni karma mods

-- TODO:
-- make sure cli-mods are reflected in config window
-- view raid snapshot events (name, dkp, dkp group)
-- turn on/off auto-snapshotting
-- allow selecting dkp group for snapshots
-- set base loot capture rarity
-- turn on/off live-dkp updating

local LOOT_QUALITY_ITEMS = {
   { text = "Poor", cvar = 0 },
   { text = "Common", cvar = 1 },
   { text = "Uncommon", cvar = 2 },
   { text = "Rare", cvar = 3 },
   { text = "Epic", cvar = 4 },
   { text = "Legendary", cvar = 5 },
   { text = "Artifact", cvar = 6 }
};

local LootQualityToColor = {
    "ff9d9d9d", -- grey
    "ffffffff", -- white
    "ff1eff00", -- green
    "ff0070dd", -- blue
    "ffa335ee", -- purple
    "ffff8000", -- orange
    "ffff0000"  -- red
}

local GConfigPanel = {};
GConfigPanel.name = Guildomatic.versionstring
GConfigPanel.okay = 
   function (self)
      self.originalValue = MY_VARIABLE;
   end

GConfigPanel.cancel =
   function (self)
      MY_VARIABLE = self.originalValue;
   end

local RootConfigPanel = nil

function GConfig:DKPLookupButton_OnClick (self)
   if (self:GetChecked()) then
      PlaySound("igMainMenuOptionCheckBoxOff");
      DKP:DoEnableLookups()

   else
      PlaySound("igMainMenuOptionCheckBoxOn");
      DKP:DoDisableLookups()
   end
end

function GConfig:DKPShowZeroButton_OnClick (self)
   if (self:GetChecked()) then
      PlaySound("igMainMenuOptionCheckBoxOff");
      DKP:DoEnableShowZeroPlayers()

   else
      PlaySound("igMainMenuOptionCheckBoxOn");
      DKP:DoDisableShowZeroPlayers()
   end

   DKP:UpdateScrollBar()
end

function GConfig:GetDefaultConfig ()
end

function GConfig:OnLoad (panel)
   -- save off our main config frame for later reference
   RootConfigPanel = panel

   local subpanel = CreateFrame("FRAME", "Guildomatic");
   panel.name = GConfigPanel.name;
   panel.okay = GConfigPanel.okay;
   panel.cancel = GConfigPanel.cancel;

   panel.defaults = GConfig:GetDefaultConfig();

   InterfaceOptions_AddCategory(panel);
end

function GConfig:LootQualityButton_OnClick (self)
   ToggleDropDownMenu(1, nil, GConfigPanelMinLootQualityFrameDropDown, self, 0, 0);
   PlaySound("igMainMenuOptionCheckBoxOn");
end

function GConfig:OnLoadLootQualityDropDown (self)
   UIDropDownMenu_Initialize(self, function (...) GConfig:LootQualityDropDown_Initialize(...) end);
   UIDropDownMenu_SetText(self, "Minimum Loot Capture Quality");
   UIDropDownMenu_SetAnchor(self, 0, 0, "TOPRIGHT", 
                            GConfigPanelMinLootQualityFrameCurrentQualityText,
                            "BOTTOMRIGHT");
end

function GConfig:LootQualityDropDown_Initialize (self)
   local info = UIDropDownMenu_CreateInfo();

   info.keepShownOnClick = 0;
   for index, value in next, LOOT_QUALITY_ITEMS do
      local crgb = LootQualityToColor[index];
      info.text = "|c" .. crgb .. value.text;
      info.func = function (...) GConfig:LootQualityDropDown_OnClick(...) end
      if ( GM_Config["LootMinQuality"] == value.cvar ) then
         info.checked = 1;
      else
         info.checked = nil;
      end
      UIDropDownMenu_AddButton(info);
   end
end

function GConfig:LootQualityDropDown_OnClick (self)
   -- update our stored minimum loot capture quality
   local newQualIndex = self:GetID()
   local newQual = LOOT_QUALITY_ITEMS[newQualIndex]
   GM_Config["LootMinQuality"] = newQual.cvar

   -- update the config panel display of the currently-selected quality
   local crgb = LootQualityToColor[newQualIndex];
   GConfigPanelMinLootQualityFrameCurrentQualityText:SetText("|c" .. crgb .. newQual.text)

   -- hide the menu as they've made a selection
   ToggleDropDownMenu(1, nil, GConfigPanelMinLootQualityFrameDropDown, self, 
                      0, 0);
end

function GConfig:OnVariablesLoaded ()
   -- set up the config panel to show the currently selected minimum loot color
   local curQualIndex = GM_Config["LootMinQuality"] + 1;
   local curQual = LOOT_QUALITY_ITEMS[curQualIndex];
   local crgb = LootQualityToColor[curQualIndex];
   GConfigPanelMinLootQualityFrameCurrentQualityText:SetText("|c" .. crgb .. 
                                                             curQual.text)

   -- set dkp enabled checkbox
   GConfigPanelDKPLookupButton:SetChecked(GM_Config["DKP_Lookups"])

   -- set show zero dkp players checkbox
   GConfigPanelDKPShowZeroButton:SetChecked(GM_Config["DKP_ShowZero"])

   -- set show minimap icon checkbox
   GConfigPanelShowMinimapButton:SetChecked(GM_Config["MinimapVisible"])
end

function GConfig:Show ()
   InterfaceOptionsFrame_OpenToCategory(RootConfigPanel)
end

function GConfig:ShowMinimapIcon_OnClick (self)
   if (self:GetChecked()) then
      PlaySound("igMainMenuOptionCheckBoxOff");
      Guildomatic:ShowMinimapIcon()

   else
      PlaySound("igMainMenuOptionCheckBoxOn");
      Guildomatic:HideMinimapIcon()
   end
end
