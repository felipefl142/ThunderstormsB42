-- Simple Debug UI for Thunder Mod
local ThunderUI = ISCollapsableWindow:derive("ThunderUI")

function ThunderUI:initialise()
    ISCollapsableWindow.initialise(self)
    self:setTitle("Weather Control")
    self:createChildren()
end

function ThunderUI:createChildren()
    ISCollapsableWindow.createChildren(self)
    
    local btnHeight = 25
    local pad = 10
    local y = 20 -- Top padding

    -- Button: Close Strike
    self.btnClose = ISButton:new(pad, y, self:getWidth() - (pad*2), btnHeight, "Force CLOSE", self, function() self:forceStrike(100) end)
    self.btnClose:initialise()
    self:addChild(self.btnClose)
    y = y + btnHeight + 5

    -- Button: Medium Strike
    self.btnMed = ISButton:new(pad, y, self:getWidth() - (pad*2), btnHeight, "Force MEDIUM", self, function() self:forceStrike(400) end)
    self.btnMed:initialise()
    self:addChild(self.btnMed)
    y = y + btnHeight + 5

    -- Button: Far Strike
    self.btnFar = ISButton:new(pad, y, self:getWidth() - (pad*2), btnHeight, "Force FAR", self, function() self:forceStrike(800) end)
    self.btnFar:initialise()
    self:addChild(self.btnFar)
    
    self:setHeight(y + btnHeight + pad)
end

function ThunderUI:forceStrike(dist)
    -- Send command to server
    local player = getPlayer()
    local args = { dist = dist }
    sendClientCommand(player, "ThunderMod", "ForceStrike", args)
end

-- MANAGER: Toggle the Window
local uiInstance = nil

local function ToggleUI()
    if not uiInstance then
        uiInstance = ThunderUI:new(100, 100, 200, 150)
        uiInstance:initialise()
        uiInstance:addToUIManager()
    else
        if uiInstance:isVisible() then
            uiInstance:setVisible(false)
            uiInstance:removeFromUIManager()
        else
            uiInstance:setVisible(true)
            uiInstance:addToUIManager()
        end
    end
end

-- INTEGRATION: Mod Options & Keybinds
-- We add a right-click context menu option for Admins/Debug to open the UI
local function OnFillWorldObjectContextMenu(player, context, worldObjects, test)
    if getDebug() or isAdmin() then
        context:addOption("Debug: Thunder UI", nil, ToggleUI)
    end
end

-- MOD OPTIONS SUPPORT (Optional Hook)
if ModOptions and ModOptions.getInstance then
    local ThunderOpts = ModOptions:getInstance("BetterThunder")
    -- If you want a dedicated toggle inside the options menu, 
    -- you would add it here, but usually ModOptions is for settings, not actions.
    -- Sticking to Context Menu is safer for UI toggling.
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
