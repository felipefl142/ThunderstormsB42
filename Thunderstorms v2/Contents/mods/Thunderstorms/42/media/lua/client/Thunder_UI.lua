print("ThunderUI: Loading script...")

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
    local y = 20 

    -- Helper to create buttons
    local function createBtn(label, dist)
        local btn = ISButton:new(pad, y, self:getWidth() - (pad*2), btnHeight, label, self, function() self:forceStrike(dist) end)
        btn:initialise()
        self:addChild(btn)
        y = y + btnHeight + 5
    end

    createBtn("Force CLOSE (200)", 200)
    createBtn("Force MEDIUM (1000)", 1000)
    createBtn("Force FAR (2500)", 2500)
    
    self:setHeight(y + pad)
end

function ThunderUI:forceStrike(dist)
    print("ThunderUI: Sending ForceStrike " .. tostring(dist))
    local player = getPlayer()
    local args = { dist = dist }
    sendClientCommand(player, "ThunderMod", "ForceStrike", args)
end

local uiInstance = nil

local function ToggleUI()
    print("ThunderUI: Toggling Window")
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

local function OnFillWorldObjectContextMenu(player, context, worldObjects, test)
    -- print("ThunderUI: Context Menu Event Fired") -- Uncomment if needed, can be spammy
    context:addOption("Debug: Thunder UI", worldObjects, function() ToggleUI() end)
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)

print("ThunderUI: Script Loaded Successfully")