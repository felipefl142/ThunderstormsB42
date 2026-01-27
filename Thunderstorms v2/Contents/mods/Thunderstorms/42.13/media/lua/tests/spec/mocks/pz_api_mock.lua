-- pz_api_mock.lua
-- Comprehensive Project Zomboid API mocks for testing

local PZMock = {}

-- Mode tracking
PZMock.currentMode = "singleplayer" -- "client", "server", "singleplayer"

-- Time tracking
PZMock.currentTime = 0

-- Random value control
PZMock.randomValues = {}
PZMock.randomIndex = 1

-- Network command tracking
PZMock.sentServerCommands = {}
PZMock.sentClientCommands = {}

-- Create ClimateManager mock
function PZMock.createClimateManager(config)
  config = config or {}

  local manager = {
    cloudIntensity = config.cloudIntensity or 0.0,
    rainIntensity = config.rainIntensity or 0.0,
    windIntensity = config.windIntensity or 0.0,

    getCloudIntensity = function(self)
      return self.cloudIntensity
    end,

    getRainIntensity = function(self)
      return self.rainIntensity
    end,

    getWindIntensity = function(self)
      return self.windIntensity
    end,

    setCloudIntensity = function(self, value)
      self.cloudIntensity = value
    end,

    setRainIntensity = function(self, value)
      self.rainIntensity = value
    end,

    setWindIntensity = function(self, value)
      self.windIntensity = value
    end
  }

  return manager
end

-- Create Core mock
function PZMock.createCore()
  return {
    getScreenWidth = function()
      return 1920
    end,

    getScreenHeight = function()
      return 1080
    end
  }
end

-- Create Room mock
function PZMock.createRoom(name)
  return {
    getName = function(self)
      return name or "TestRoom"
    end
  }
end

-- Create IsoGridSquare mock
function PZMock.createSquare(config)
  config = config or {}

  return {
    room = config.room,

    getRoom = function(self)
      return self.room
    end,

    setRoom = function(self, room)
      self.room = room
    end
  }
end

-- Create IsoPlayer mock
function PZMock.createPlayer(config)
  config = config or {}

  local square = config.square or PZMock.createSquare()

  return {
    square = square,

    getSquare = function(self)
      return self.square
    end,

    setSquare = function(self, newSquare)
      self.square = newSquare
    end
  }
end

-- Create IsoCell mock with lighting system
function PZMock.createCell()
  local cell = {
    lampposts = {},

    addLamppost = function(self, x, y, z, radius, r, g, b)
      local lamppost = {
        x = x, y = y, z = z,
        radius = radius,
        r = r, g = g, b = b,
        timestamp = PZMock.currentTime
      }
      table.insert(self.lampposts, lamppost)
      return lamppost
    end,

    removeLamppost = function(self, lamppost)
      for i = #self.lampposts, 1, -1 do
        if self.lampposts[i] == lamppost then
          table.remove(self.lampposts, i)
          return true
        end
      end
      return false
    end,

    _clearLampposts = function(self)
      self.lampposts = {}
    end,

    _getLamppostCount = function(self)
      return #self.lampposts
    end
  }

  return cell
end

-- Create SoundManager mock
function PZMock.createSoundManager()
  local manager = {
    sounds = {},

    PlayWorldSound = function(self, soundName, square, volume, radius, pitch, periodic)
      local sound = {
        name = soundName,
        square = square,
        volume = volume or 1.0,
        radius = radius or 100,
        pitch = pitch or 1.0,
        periodic = periodic or false,
        timestamp = PZMock.currentTime
      }
      table.insert(self.sounds, sound)
      return sound
    end,

    _clearSounds = function(self)
      self.sounds = {}
    end,

    _getSoundCount = function(self)
      return #self.sounds
    end,

    _getLastSound = function(self)
      return self.sounds[#self.sounds]
    end
  }

  return manager
end

-- Create ISUIElement mock
function PZMock.createISUIElement()
  local element = {
    x = 0,
    y = 0,
    width = 0,
    height = 0,
    backgroundColor = {r=0, g=0, b=0, a=0},
    visible = true,
    ignoreHeightChange = true,
    ignoreLossControl = true,

    initialise = function(self) end,

    render = function(self) end,

    setX = function(self, x)
      self.x = x
    end,

    setY = function(self, y)
      self.y = y
    end,

    setWidth = function(self, width)
      self.width = width
    end,

    setHeight = function(self, height)
      self.height = height
    end,

    setVisible = function(self, visible)
      self.visible = visible
    end,

    addToUIManager = function(self)
      self.inUIManager = true
    end,

    removeFromUIManager = function(self)
      self.inUIManager = false
    end
  }

  return element
end

-- Create Events mock
PZMock.Events = {
  OnTick = {
    Add = function(callback)
      if not PZMock.Events._callbacks["OnTick"] then
        PZMock.Events._callbacks["OnTick"] = {}
      end
      table.insert(PZMock.Events._callbacks["OnTick"], callback)
    end
  },
  OnRenderTick = {
    Add = function(callback)
      if not PZMock.Events._callbacks["OnRenderTick"] then
        PZMock.Events._callbacks["OnRenderTick"] = {}
      end
      table.insert(PZMock.Events._callbacks["OnRenderTick"], callback)
    end
  },
  OnServerCommand = {
    Add = function(callback)
      if not PZMock.Events._callbacks["OnServerCommand"] then
        PZMock.Events._callbacks["OnServerCommand"] = {}
      end
      table.insert(PZMock.Events._callbacks["OnServerCommand"], callback)
    end
  },
  OnClientCommand = {
    Add = function(callback)
      if not PZMock.Events._callbacks["OnClientCommand"] then
        PZMock.Events._callbacks["OnClientCommand"] = {}
      end
      table.insert(PZMock.Events._callbacks["OnClientCommand"], callback)
    end
  },
  OnThunder = {
    Add = function(callback)
      if not PZMock.Events._callbacks["OnThunder"] then
        PZMock.Events._callbacks["OnThunder"] = {}
      end
      table.insert(PZMock.Events._callbacks["OnThunder"], callback)
    end
  },

  _callbacks = {},

  Add = function(eventName, callback)
    if not PZMock.Events._callbacks[eventName] then
      PZMock.Events._callbacks[eventName] = {}
    end
    table.insert(PZMock.Events._callbacks[eventName], callback)
  end,

  _trigger = function(eventName, ...)
    local callbacks = PZMock.Events._callbacks[eventName]
    if callbacks then
      for _, callback in ipairs(callbacks) do
        callback(...)
      end
    end
  end,

  _clear = function(eventName)
    if eventName then
      PZMock.Events._callbacks[eventName] = {}
    else
      PZMock.Events._callbacks = {}
    end
  end
}

-- Time control
function PZMock.getTimestampMs()
  return PZMock.currentTime
end

function PZMock.advanceTime(ms)
  PZMock.currentTime = PZMock.currentTime + ms
end

function PZMock.resetTime()
  PZMock.currentTime = 0
end

-- Random control
function PZMock.ZombRandFloat(min, max)
  if #PZMock.randomValues > 0 then
    local value = PZMock.randomValues[PZMock.randomIndex]
    PZMock.randomIndex = (PZMock.randomIndex % #PZMock.randomValues) + 1
    return min + (max - min) * value
  end
  return min + (max - min) * math.random()
end

function PZMock.ZombRand(min, max)
  -- ZombRand can be called with 1 or 2 arguments
  if max == nil then
    -- Single argument: ZombRand(max) returns 0 to max-1
    max = min
    min = 0
  end

  if #PZMock.randomValues > 0 then
    local value = PZMock.randomValues[PZMock.randomIndex]
    PZMock.randomIndex = (PZMock.randomIndex % #PZMock.randomValues) + 1
    return math.floor(min + value * (max - min))
  end
  return math.random(min, max - 1)
end

function PZMock.setRandomValues(values)
  PZMock.randomValues = values
  PZMock.randomIndex = 1
end

function PZMock.resetRandom()
  PZMock.randomValues = {}
  PZMock.randomIndex = 1
end

-- Network mocking
function PZMock.sendServerCommand(module, command, args)
  table.insert(PZMock.sentServerCommands, {
    module = module,
    command = command,
    args = args,
    timestamp = PZMock.currentTime
  })
end

function PZMock.sendClientCommand(player, module, command, args)
  table.insert(PZMock.sentClientCommands, {
    player = player,
    module = module,
    command = command,
    args = args,
    timestamp = PZMock.currentTime
  })
end

function PZMock.clearNetworkCommands()
  PZMock.sentServerCommands = {}
  PZMock.sentClientCommands = {}
end

-- Client/Server mode control
function PZMock.isClient()
  return PZMock.currentMode == "client" or PZMock.currentMode == "singleplayer"
end

function PZMock.isServer()
  return PZMock.currentMode == "server" or PZMock.currentMode == "singleplayer"
end

function PZMock.setClientMode()
  PZMock.currentMode = "client"
end

function PZMock.setServerMode()
  PZMock.currentMode = "server"
end

function PZMock.setSinglePlayerMode()
  PZMock.currentMode = "singleplayer"
end

-- Global instances
local climateManager = nil
local soundManager = nil
local cell = nil
local player = nil

-- Install all mocks at once
function PZMock.installAll(config)
  config = config or {}

  -- Climate
  climateManager = PZMock.createClimateManager(config.climate)
  _G.getClimateManager = function() return climateManager end

  -- Core
  _G.getCore = PZMock.createCore

  -- Sound
  soundManager = PZMock.createSoundManager()
  _G.getSoundManager = function() return soundManager end

  -- Cell
  cell = PZMock.createCell()
  _G.getCell = function() return cell end

  -- Player
  player = PZMock.createPlayer(config.player or {})
  _G.getPlayer = function() return player end

  -- Events
  _G.Events = PZMock.Events

  -- Time
  _G.getTimestampMs = PZMock.getTimestampMs

  -- Random
  _G.ZombRandFloat = PZMock.ZombRandFloat
  _G.ZombRand = PZMock.ZombRand

  -- Network
  _G.sendServerCommand = PZMock.sendServerCommand
  _G.sendClientCommand = PZMock.sendClientCommand

  -- Client/Server detection
  _G.isClient = PZMock.isClient
  _G.isServer = PZMock.isServer

  -- ISUIElement
  _G.ISUIElement = PZMock.createISUIElement()

  return {
    climateManager = climateManager,
    soundManager = soundManager,
    cell = cell,
    player = player
  }
end

-- Cleanup all mocks
function PZMock.cleanupAll()
  PZMock.resetTime()
  PZMock.resetRandom()
  PZMock.clearNetworkCommands()
  PZMock.Events._clear()

  if climateManager then
    climateManager.cloudIntensity = 0.0
    climateManager.rainIntensity = 0.0
    climateManager.windIntensity = 0.0
  end

  if soundManager then
    soundManager:_clearSounds()
  end

  if cell then
    cell:_clearLampposts()
  end
end

return PZMock
