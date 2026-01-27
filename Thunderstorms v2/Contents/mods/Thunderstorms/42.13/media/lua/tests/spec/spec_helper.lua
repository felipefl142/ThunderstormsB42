-- spec_helper.lua
-- Shared test utilities and mock management system for Busted tests

local MockManager = {}

-- Store original global state
MockManager.savedGlobals = {}

-- Save original global values before installing mocks
function MockManager.saveGlobals(keys)
  for _, key in ipairs(keys) do
    MockManager.savedGlobals[key] = _G[key]
  end
end

-- Restore original global values after tests
function MockManager.restoreGlobals()
  for key, value in pairs(MockManager.savedGlobals) do
    _G[key] = value
  end
  MockManager.savedGlobals = {}
end

-- Install a mock globally
function MockManager.installMock(name, mock)
  if not MockManager.savedGlobals[name] then
    MockManager.savedGlobals[name] = _G[name]
  end
  _G[name] = mock
end

-- Create a spy function that tracks calls
function MockManager.createSpy(returnValue)
  local spy = {
    called = false,
    callCount = 0,
    lastArgs = nil,
    allArgs = {},
    returnValue = returnValue
  }

  local mt = {
    __call = function(self, ...)
      self.called = true
      self.callCount = self.callCount + 1
      self.lastArgs = {...}
      table.insert(self.allArgs, {...})
      return self.returnValue
    end
  }

  setmetatable(spy, mt)
  return spy
end

-- Reset a spy's state
function MockManager.resetSpy(spy)
  spy.called = false
  spy.callCount = 0
  spy.lastArgs = nil
  spy.allArgs = {}
end

return MockManager
