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

-- Prevent garbage collector from collecting EvalClient when ui_world_2d stops running
rawset(_G, "EvalClient", EvalClient)

function EvalClient:Init()
  EA:LuaOutput("EVAL", "Initializing EvalClient")

  local _COMM = {
    -- Create some entries in the communication table, these entries will be read by Eval Server and set to values.
    evalBuffer = "", -- String reference to the eval buffer, which is modified by Eval Server to contain Lua Bytecode
    requestedEvalBufferSize = 0, -- The requested size of the eval buffer, if the current buffer isn't big enough.
    evalServerConnected = false, -- Eval Server flips this to true when its connected to Eval Client
    evalServerConnectionAck = false, -- Eval Client flips this to true when it sees that Eval Server is connected.
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

  self.jobs = {}

  self:InstallYieldOverload()
end

function EvalClient:InstallYieldOverload()
  EA:LuaOutput("EVAL", "Installing Yield Overload")

  -- We want to install a frame callback in ui_world_2d
  local OldYield = Yield
  rawset(_G, "Yield", function()
    self:RunFrame()
    if self:StartFrameJob("ui_world_2d") then
      --if self.yieldOverloadInstalled then
      --  self:UninstallYieldOverload(OldYield)
      --end
    end
    OldYield()
  end)
  self.yieldOverloadInstalled = true
end

function EvalClient:StartFrameJob(world)
  if not self.jobs[world] then
    local worldObj = Universe:GetWorld(world)

    if worldObj then
      EA:LuaOutput("EVAL", "Found "..world..", installing frame callback.")

      local job = Classes.Job_PerFrameFunctionCallback:Spawn(function()
        self:RunFrame()
      end, "EvalClientJob", worldObj)

      job:ExecuteAsIs()

      self.jobs[world] = job

      return true, job
    end
  end

  return false, self.jobs[world]
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
      _COMM.evalServerConnectionAck = true
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
