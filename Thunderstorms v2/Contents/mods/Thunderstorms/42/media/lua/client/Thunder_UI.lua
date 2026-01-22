require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISPanel"

print("[ThunderUI] ========== LOADING ==========")

-- Global table to hold our UI class and instance
ThunderModUI = ISCollapsableWindow:derive("ThunderModUI")
ThunderModUI.instance = nil
ThunderModUI.DEBUG = true

local function DebugPrint(msg)
    if ThunderModUI.DEBUG then
        print("[ThunderUI] " .. msg)
    end
end

function ThunderModUI:new(x, y, width, height)
    DebugPrint("Creating new window at " .. x .. "," .. y .. " size " .. width .. "x" .. height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.resizable = false
    return o
end

function ThunderModUI:initialise()
    ISCollapsableWindow.initialise(self)
    self:setTitle("Thunder Control")
    self:setResizable(false)
    DebugPrint("Window initialized")
end

function ThunderModUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local btnHeight = 25
    local pad = 10
    local width = self:getWidth()
    local y = self:titleBarHeight() + pad

    DebugPrint("Creating children, starting y=" .. y)

    -- 1. BUTTONS
    local function createBtn(label, dist)
        local btn = ISButton:new(pad, y, width - (pad*2), btnHeight, label, self, function() self:forceStrike(dist) end)
        btn:initialise()
        btn.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
        self:addChild(btn)
        y = y + btnHeight + 5
        DebugPrint("  Created button: " .. label)
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
    DebugPrint("Window height set to " .. y)
end

function ThunderModUI:updateFrequency()
    local val = self.sliderVal
    DebugPrint("Setting frequency to " .. tostring(val))

    local player = getPlayer()
    if player then
        DebugPrint("Sending SetFrequency command to server")
        sendClientCommand(player, "ThunderMod", "SetFrequency", { frequency = val })
    else
        DebugPrint("ERROR: No player found!")
    end
end

function ThunderModUI:forceStrike(dist)
    DebugPrint("Force Strike button pressed, dist=" .. tostring(dist))

    local player = getPlayer()
    if player then
        DebugPrint("Sending ForceStrike command to server")
        sendClientCommand(player, "ThunderMod", "ForceStrike", { dist = dist })
    else
        DebugPrint("ERROR: No player found!")
    end
end

-- 3. GLOBAL FUNCTIONS
function ThunderModUI_Toggle()
    DebugPrint("Toggle called")

    if not ThunderModUI.instance then
        DebugPrint("Creating new UI instance")
        ThunderModUI.instance = ThunderModUI:new(100, 100, 250, 200)
        ThunderModUI.instance:initialise()
        ThunderModUI.instance:addToUIManager()
        ThunderModUI.instance:setVisible(true)
        DebugPrint("UI instance created and shown")
    else
        if ThunderModUI.instance:isVisible() then
            DebugPrint("Hiding UI")
            ThunderModUI.instance:setVisible(false)
            ThunderModUI.instance:removeFromUIManager()
        else
            DebugPrint("Showing UI")
            ThunderModUI.instance:setVisible(true)
            ThunderModUI.instance:addToUIManager()
        end
    end
end

-- 4. EVENTS
local function OnContext(playerNum, context, worldObjects, test)
    if test then return true end
    context:addOption("Thunder Control", nil, ThunderModUI_Toggle)
    DebugPrint("Added context menu option (world)")
end

Events.OnFillWorldObjectContextMenu.Add(OnContext)

local function OnInventoryContext(playerNum, context, items)
    context:addOption("Thunder Control", nil, ThunderModUI_Toggle)
    DebugPrint("Added context menu option (inventory)")
end

Events.OnFillInventoryObjectContextMenu.Add(OnInventoryContext)

-- Keybind: Press K to toggle
local function OnKeyPressed(key)
    if key == Keyboard.KEY_K then
        DebugPrint("K key pressed")
        ThunderModUI_Toggle()
    end
end

Events.OnKeyPressed.Add(OnKeyPressed)

print("[ThunderUI] ========== LOADED ==========")
print("[ThunderUI] Hotkey: K | Context menu: 'Thunder Control'")
