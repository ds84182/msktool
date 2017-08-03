if not dolphin then error("This script must be running inside of Dolphin to work!") end

-- To use the eval server, type: require "msk_eval.eval_server.init" into the Dolphin console

dolphin.log("Starting Eval Server")

-- Patch MSK::phonyprint to call luaB_print
dolphin.memory.writeU32(0x8031f6b0, 0x4be2b4f0)
dolphin.memory.invalidateICache(0x8031f6b0, 8, true)

dolphin.log("MSK::phonyprint patched to call luaB_print")

eval_server = {}

local function packageResolve(pkg)
	local pkgPath = pkg:gsub("%.", "/")
	for path in package.path:gmatch("([^;]+);?") do
		local formattedPath = path:gsub("?", pkgPath)
		local fh = io.open(formattedPath, "r")
		if fh then
			fh:close()
			return formattedPath
		end
	end
  error("eval_server cannot resolve package path to "..pkg)
end

eval_server.packagePath = packageResolve(...)
dolphin.log("Resolved package dir: "..eval_server.packagePath)
eval_server.mskevalRoot = eval_server.packagePath.."/../.."
eval_server.msktoolPath = eval_server.packagePath.."/../../../.."
dolphin.log("msktool bin path: "..eval_server.msktoolPath.."/bin/main.dart")

require "msk_eval.eval_server.value_reader"

local MVAZ_MEM_START = 0x80600000
local MVAZ_MEM_END = 0x80900000

local _COMM_ADDR

function eval_server.onFrame_FindCOMMLSB()
  -- Locate the _COMM LSB to get the table pointer
  -- Look for "MVAZtable: 0x"
  local findStr = "MVAZtable: 0x"
  for addr=MVAZ_MEM_START, MVAZ_MEM_END, 4 do
    local found = true
    for i=1, #findStr do
      if dolphin.memory.readU8(addr+i-1) ~= findStr:byte(i) then
        found = false
        break
      end
    end
    if found then
      local tableAddrStr = {}
      for i=1, 8 do
        tableAddrStr[i] = string.char(dolphin.memory.readU8(addr+#findStr+i-1))
      end
      tableAddrStr = table.concat(tableAddrStr)
      dolphin.log(("Found at %08X (table address: %s)"):format(addr, tableAddrStr))
      local addr = tonumber(tableAddrStr, 16)
      if addr and addr >= 0x80000000 then
        _COMM_ADDR = addr
        _G._COMM_ADDR = addr
        eval_server.onFrame = eval_server.onFrame_InitCOMM
        break
      end
    end
  end
end

function eval_server.onFrame_InitCOMM()
  local evalServerConnSlot = eval_server.getTable(_COMM_ADDR, "evalServerConnected")
  eval_server.overwriteTableValue(_COMM_ADDR, evalServerConnSlot, true)

  eval_server.onFrame = eval_server.onFrame_WaitAck
end

function eval_server.onFrame_WaitAck()
  local evalServerConnectionAckSlot, evalServerConnectionAckTValue = eval_server.findTable(_COMM_ADDR, "evalServerConnectionAck")
  if evalServerConnectionAckSlot then
    local ack = eval_server.readTValue(evalServerConnectionAckTValue)

    if ack then
      dolphin.log("Eval server connection acknowledged!")

      eval_server.onFrame = eval_server.onFrame_GrabResults

      -- Send Common.luac over and execute it
      -- Otherwise the game refuses to run (lots of scripts will error)
      dolphin.log("Sending over Common...")
      evalBC(eval_server.mskevalRoot.."/Common.luac")
    end
  end
end

function eval_server.onFrame_GrabResults()
  -- TODO: Grab results
end

eval_server.onFrame = eval_server.onFrame_FindCOMMLSB

function evalBC(path)
  local bc = io.open(path, "rb")
  local bcdata = bc:read("*a")
  bc:close()

  local evalBufferSlot, evalBufferTValue = eval_server.findTable(_COMM_ADDR, "evalBuffer")

  local function finishEval()
    eval_server.replaceStringData(evalBufferTValue, bcdata)

    local requestEvalSlot = eval_server.getTable(_COMM_ADDR, "requestEval")
    eval_server.overwriteTableValue(_COMM_ADDR, requestEvalSlot, true)
    dolphin.log("Eval finished")
  end

  local bufferLen = eval_server.stringLen(evalBufferTValue)
  if bufferLen < #bcdata then
    -- Request buffer resize
    local oldOnFrame = eval_server.onFrame

    dolphin.log("Requesting buffer resize")
    dolphin.log("Old buffer "..bufferLen..", New buffer >="..(#bcdata))

    local requestedEvalBufferSizeSlot = eval_server.getTable(_COMM_ADDR, "requestedEvalBufferSize")
    eval_server.overwriteTableValue(_COMM_ADDR, requestedEvalBufferSizeSlot, #bcdata)

    eval_server.onFrame = function()
      evalBufferSlot, evalBufferTValue = eval_server.findTable(_COMM_ADDR, "evalBuffer")
      local oldBufferLen = bufferLen
      local bufferLen = eval_server.stringLen(evalBufferTValue)
      dolphin.log("Old buffer "..oldBufferLen..", Current buffer "..bufferLen..", New buffer >="..(#bcdata))
      if bufferLen >= #bcdata then
        finishEval()
        eval_server.onFrame = oldOnFrame
      else
        dolphin.log(bufferLen.." "..#bcdata)
      end
    end
  else
    finishEval()
  end
end

function eval(str)
  local func, err = loadstring(str)
  if not func then
    dolphin.log("Compilation failed: "..err)
    return
  end

  local fh = io.open(".eval_temp.lua", "w")
  fh:write(str)
  fh:close()

  local result = os.execute("dart "..eval_server.msktoolPath.."/bin/main.dart compile .eval_temp.lua")
  if (not result) or (type(result) == "number" and result ~= 0) then
    dolphin.log("Compilation failed")
    return
  end

  evalBC(".eval_temp-ppc.luac")
end

cheats = {}

function cheats.unlockAll()
  eval [[
    for _, collection in ipairs(Luattrib:GetAllCollections("unlock")) do
      Unlocks:Unlock(collection[1], collection[2])
    end
  ]]
end

dolphin.onFrame(function()
  eval_server.onFrame()
end)
