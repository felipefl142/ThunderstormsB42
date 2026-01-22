-- Explicitly require ISUI classes to ensure they are loaded
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISPanel"

print("ThunderModUI: File Loaded")

-- Global table to hold our UI class and instance
ThunderModUI = ISCollapsableWindow:derive("ThunderModUI")
ThunderModUI.instance = nil

function ThunderModUI:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.resizable = false
    return o
end

function ThunderModUI:initialise()
    ISCollapsableWindow.initialise(self)
    self:setTitle("Weather Control")
    self:setResizable(false)
end

function ThunderModUI:createChildren()
    ISCollapsableWindow.createChildren(self)
    
    local btnHeight = 25
    local pad = 10
    local width = self:getWidth()
    local y = self:titleBarHeight() + pad

    -- 1. BUTTONS
    local function createBtn(label, dist)
        local btn = ISButton:new(pad, y, width - (pad*2), btnHeight, label, self, function() self:forceStrike(dist) end)
        btn:initialise()
        btn.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
        self:addChild(btn)
        y = y + btnHeight + 5
    end

    createBtn("Force CLOSE (200)", 200)
    createBtn("Force MEDIUM (1000)", 1000)
    createBtn("Force FAR (2500)", 2500)
    
    y = y + 10
    
    -- 2. FREQUENCY SLIDER
    local lbl = ISLabel:new(pad, y, 20, "Frequency (Chance):", 1, 1, 1, 1, UIFont.Small, true)
    lbl:initialise()
    self:addChild(lbl)
    
    self.freqLabel = ISLabel:new(width - pad - 30, y, 20, "1.0", 1, 1, 1, 1, UIFont.Small, true)
    self.freqLabel:initialise()
    self:addChild(self.freqLabel)
    
    y = y + 20
    
    local sliderH = 20
    local sliderW = width - (pad*2)
    self.sliderVal = 1.0
    self.sliderMax = 5.0
    
    local slider = ISPanel:new(pad, y, sliderW, sliderH)
    slider:initialise()
    slider:setBackgroundColor(0, 0, 0, 0.5)
    
    slider.render = function(s)
        s:drawRect(0, s:getHeight()/2 - 1, s:getWidth(), 2, 1, 0.5, 0.5, 0.5)
        local pct = self.sliderVal / self.sliderMax
        pct = math.max(0, math.min(1, pct))
        local kx = pct * (s:getWidth() - 10)
        s:drawRect(kx, 2, 10, 16, 1, 0.9, 0.9, 0.9)
    end
    
    slider.onMouseDown = function(s, x, y) s.dragging = true end
    slider.onMouseUp = function(s, x, y) 
        s.dragging = false
        self:updateFrequency()
    end
    slider.onMouseUpOutside = slider.onMouseUp
    slider.onMouseMove = function(s, dx, dy)
        if s.dragging then
            local mx = s:getMouseX()
            local pct = mx / (s:getWidth() - 10)
            pct = math.max(0, math.min(1, pct))
            self.sliderVal = math.floor((pct * self.sliderMax) * 10 + 0.5) / 10
            self.freqLabel.name = tostring(self.sliderVal)
        end
    end
    slider.onMouseMoveOutside = slider.onMouseMove
    
    self:addChild(slider)
    y = y + sliderH + 10
    
    self:setHeight(y)
end

function ThunderModUI:updateFrequency()
    local val = self.sliderVal
    print("ThunderModUI: Setting frequency to " .. tostring(val))
    local player = getPlayer()
    if player then
        sendClientCommand(player, "ThunderMod", "SetFrequency", { frequency = val })
    end
end

function ThunderModUI:forceStrike(dist)
    print("ThunderModUI: Force Strike " .. tostring(dist))
    local player = getPlayer()
    if player then
        sendClientCommand(player, "ThunderMod", "ForceStrike", { dist = dist })
    end
end

-- 3. GLOBAL FUNCTIONS
function ThunderModUI_Toggle()
    if not ThunderModUI.instance then
        print("ThunderModUI: Creating new instance")
        ThunderModUI.instance = ThunderModUI:new(100, 100, 250, 200)
        ThunderModUI.instance:initialise()
        ThunderModUI.instance:addToUIManager()
        ThunderModUI.instance:setVisible(true)
    else
        if ThunderModUI.instance:isVisible() then
            ThunderModUI.instance:setVisible(false)
            ThunderModUI.instance:removeFromUIManager()
        else
            ThunderModUI.instance:setVisible(true)
            ThunderModUI.instance:addToUIManager()
        end
    end
end

-- 4. EVENTS
local function OnContext(playerNum, context, worldObjects, test)
    if test then return true end
    context:addOption("Weather Control (Thunder)", nil, ThunderModUI_Toggle)
end

Events.OnFillWorldObjectContextMenu.Add(OnContext)

-- Also add to inventory context menu as backup
local function OnInventoryContext(playerNum, context, items)
    context:addOption("Weather Control (Thunder)", nil, ThunderModUI_Toggle)
end

Events.OnFillInventoryObjectContextMenu.Add(OnInventoryContext)

-- Keybind alternative (press F7 to toggle)
local function OnKeyPressed(key)
    if key == Keyboard.KEY_F7 then
        ThunderModUI_Toggle()
    end
end

Events.OnKeyPressed.Add(OnKeyPressed)

print("ThunderModUI: Events Registered (Context + F6 keybind)")