-- Eval Client - Compiled to Lua Bytecode, retargeted to PowerPC, and run as GameplayLoad in My Sims Kingdom

-- We place strings in Lua's memory that are found by Eval Server.
-- Eval Server then modifies the strings to relay messages to us.

-- We take advantage of the fact that Lua allows multiple copies of large strings.
-- So we create a large string buffer of something unique.

-- string.rep doesn't trash the heap with copies, so we use it extensively.

-- For back and forth communication, we set up a table that gets modified by Eval Server.
-- Since table objects leak their address, we can set up a string buffer that contains the table's address.

-- Enable logging

EA:LuaOutput("EVAL", "Setting up environment...")

function EA:LogLevel(tag, level, ...)
  EA:LuaOutput(tag, ...)
end

for setting in pairs(Log_Settings) do
  Log_Settings[setting] = EA.kLevelAll
end

function print(...)
  EA:LuaOutput("PRINT", ...)
end

rawset(_G, "LuaPcallErrorFunction", function(...)
  EA:LuaOutput("Lua", ...)
end)

local EvalClient = {}

function EvalClient:Init()
  EA:LuaOutput("EVAL", "Initializing EvalClient")

  local _COMM = {
    -- Create some entries in the communication table, these entries will be read by Eval Server and set to values.
    evalBuffer = "", -- String reference to the eval buffer, which is modified by Eval Server to contain Lua Bytecode
    requestedEvalBufferSize = 0, -- The requested size of the eval buffer, if the current buffer isn't big enough.
    evalServerConnected = false, -- Eval Server flips this to true when its connected to Eval Client
    requestEval = false, -- Eval Server flips this to true when it wants the evalBuffer to be evaluated
    evalResult = nil, -- Evaluation result, Eval Server reads this
  }

  local LSB_SIZE = 1024

  local function lsb(baseData)
    -- if #baseData == 4: baseData:rep(256) -> len of 1024 == LSB_SIZE
    return baseData:rep(math.ceil(LSB_SIZE/#baseData))
  end

  -- Leak the location of _COMM though a LSB
  self.commLeak = lsb("MVAZ"..tostring(_COMM))

  self._COMM = _COMM

  self:InstallYieldOverload()
end

function EvalClient:InstallYieldOverload()
  EA:LuaOutput("EVAL", "Installing Yield Overload")

  -- We want to install a frame callback in ui_world_2d
  local OldYield = Yield
  rawset(_G, "Yield", function()
    OldYield()

    local uiWorld = Universe:GetWorld("ui_world_2d")

    if uiWorld and not self.job then
      EA:LuaOutput("EVAL", "Found UI World 2D, installing frame callback.")

      self.job = Classes.Job_PerFrameFunctionCallback:Spawn(function()
        if self.yieldOverloadInstalled then
          self:UninstallYieldOverload(OldYield)
        end
        self:RunFrame()
      end, "EvalClientJob", uiWorld)

      self.job:ExecuteAsIs()
    end
  end)
  self.yieldOverloadInstalled = true
end

function EvalClient:UninstallYieldOverload(OldYield)
  EA:LuaOutput("EVAL", "Uninstalling Yield Overload")

  self.yieldOverloadInstalled = nil
  rawset(_G, "Yield", OldYield)
end

function EvalClient:RunFrame()
  local _COMM = self._COMM
  if not _COMM.evalServerConnected then
    EA:LuaOutput("EVAL", "Waiting for Eval Server to connect to "..tostring(_COMM))
  else
    if not self.connected then
      EA:LuaOutput("EVAL", "Eval Server connected!")
      self.connected = true
    end

    if _COMM.requestedEvalBufferSize > #_COMM.evalBuffer then
      EA:LuaOutput("EVAL", "Grow eval buffer size to ".._COMM.requestedEvalBufferSize)
      -- Grow the evaluation buffer to the requested size
      local evalPlaceholder = "MSK_EVAL"
      _COMM.evalBuffer = evalPlaceholder:rep(math.ceil(_COMM.requestedEvalBufferSize/#evalPlaceholder))
      -- Set the requestedEvalBufferSize to 0 to signal the Eval Server to continue
      _COMM.requestedEvalBufferSize = 0
    end

    if _COMM.requestEval then
      EA:LuaOutput("EVAL", "Eval requested")
      local func = loadstring(_COMM.evalBuffer)
      _COMM.evalResult = {pcall(func)}
      _COMM.requestEval = false
    end
  end
end

System:RegisterGeneralPostLoadInit(EvalClient.Init, EvalClient)
