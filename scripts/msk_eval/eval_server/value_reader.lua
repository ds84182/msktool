-- Reads values from Lua into Lua because... Lua.
-- Simple values are read directly into the Lua equivalent.
-- This includes nil, boolean, lightuserdata, number, and string.
-- More complex values like table, function, userdata, and thread, are read as GCObject addresses.
-- There are special methods to handle these complex values.

local ffi = require "ffi"
local bit = require "bit"

local valueTypes = {
  NIL = 0,
  BOOLEAN = 1,
  LIGHTUSERDATA = 2,
  NUMBER = 3,
  STRING = 4,
  -- Not serializable
  TABLE = 5,
  FUNCTION = 6,
  USERDATA = 7,
  THREAD = 8
}
--[[
union Value {     [offset:  0, size:  4]
  GCObject *gc;   [size:  4]
  void *p;        [size:  4]
  float n;        [size:  4]
  int b;          [size:  4]
};

struct TValue {   [size:  8]
  Value value;    [offset:  0, size:  4]
  int tt;         [offset:  4, size:  4]
};

struct GCHeader : CommonHeader; [size: 8]

union GCObject { [size:  ]
  GCHeader gch;   [size:  8]
  TString ts;
  Udata u;
  Closure cl;
  Table h;
  Proto p;
  UpVal uv;
  lua_State th; /* thread */
};

struct CommonHeader { [size:  6, padding:  2]
  GCObject *next; [offset:  0, size:  4]
  uint8_t tt;     [offset:  4, size:  1]
  uint8_t marked; [offset:  5, size:  1]
};

struct TString : CommonHeader { [offset:  6, size: 20]
  uint8_t reserved;     [offset:  6, size: 1]
  padding;              [offset:  7, size: 1]
  uint32_t hash;        [offset:  8, size: 4]
  size_t len;           [offset: 12, size: 4]
  void data_start;      [offset: 16]
};

struct Udata : CommonHeader { [offset:  6, size: 16]
  padding;                    [offset:  6, size:  2]
  Table *metatable;           [offset:  8, size:  4]
  Table *env;                 [offset: 12, size:  4]
  size_t len;                 [offset: 16, size:  4]
  void data_start;            [offset: 16]
};

// Proto redacted, not interacted with.

// UpVal redacted, not interacted with.

// lua_State redacted, not interacted with.

// Closure redacted, not interacted with.

// CClosure redacted, not interacted with.

// LClosure redacted, not interacted with.

union TKey {                        [offset:  0, size: 12]
  struct : TValue {                 [offset:  8, size: 12]
    Node *next; /* for chaining */  [offset:  8, size:  4]
  } nk;
  TValue tvk;                       [size:  8]
};

struct Node {   [size: 20]
  TValue i_val; [offset:  0, size:  8]
  TKey i_key;   [offset:  8, size: 12]
};

struct Table : CommonHeader {                                     [offset:  6, size: 32]
  uint8_t flags; /* 1 << p means tagmethod(p) is not present */   [offset:  6, size:  1]
  uint8_t lsizenode; /* log2 of size of `node` array */           [offset:  7, size:  1]
  Table *metatable;                                               [offset:  8, size:  4]
  TValue *array; /* array part */                                 [offset: 12, size:  4]
  Node *node;                                                     [offset: 16, size:  4]
  Node *lastfree; /* any free position is before this position */ [offset: 20, size:  4]
  GCObject *gclist;                                               [offset: 24, size:  4]
  int sizearray; /* size of `array` array */                      [offset: 28, size:  4]
};
]]

-- Do some code generation to make getter/setter functions from dolphin.memory functions.
local function makeGS(offset, rwfunc)
  return assert(loadstring([=[
return function(address, value)
if value ~= nil then
  ]=]..rwfunc.write..[=[(address + ]=]..offset..[=[, value)
else
  return ]=]..rwfunc.read..[=[(address + ]=]..offset..[=[)
end
end]=]))()
end

-- Do some code generation to make a function that always returns an offset to the given address.
local function makeO(offset)
  return loadstring("return function(address) return address + "..offset.." end")()
end

local U8 = {
  read = "dolphin.memory.readU8",
  write = "dolphin.memory.writeU8",
}
local U32 = {
  read = "dolphin.memory.readU32",
  write = "dolphin.memory.writeU32",
}
local PTR = U32
local F32 = {
  read = "dolphin.memory.readF32",
  write = "dolphin.memory.writeF32",
}

if not dolphin.memory.readF32 then
  -- Earlier versions of dolphin.lua did not have the ability to read F32s.
  -- Patch it!
  local cast = ffi.typeof "union { uint32_t i; float f; }"
  local readU32, writeU32 = dolphin.memory.readU32, dolphin.memory.writeU32
  function dolphin.memory.readF32(address)
    local caster = cast()
    caster.i = readU32(address)
    return caster.f
  end
  function dolphin.memory.writeF32(address, value)
    local caster = cast()
    caster.f = value
    writeU32(address, caster.i)
  end
end

------------------------------------------------------------------------------
-- Struct read/write functions:                                             --
------------------------------------------------------------------------------

local value = {
  pointer = makeGS(0, PTR),
  number = makeGS(0, F32),
  boolean = makeGS(0, U32),
}
value.gco = value.pointer

local TV_TT = 4
local SIZEOF_TV = 8

local tvalue = {
  type = makeGS(TV_TT, U32),
}

local CH_NEXT, CH_TT, CH_MARKED = 0, 4, 5

local commonHeader = {
  next = makeGS(CH_NEXT, U32),
  type = makeGS(CH_TT, U8),
  marked = makeGS(CH_MARKED, U8)
}

local TS_HASH, TS_LEN, TS_DATA = 8, 12, 16

local tstring = {
  hash = makeGS(TS_HASH, U32),
  len = makeGS(TS_LEN, U32),
  address = makeO(TS_DATA),
}

-- TODO: udata

local TK_NEXT = 8

local tkey = {
  next = makeGS(TK_NEXT, PTR),
}

local N_VAL, N_KEY = 0, 8
local SIZEOF_NODE = 20

local node = {
  val = makeO(N_VAL),
  key = makeO(N_KEY),
}

local TTAB_FLAGS, TTAB_LSIZENODE, TTAB_METATABLE, TTAB_ARRAY, TTAB_NODE, TTAB_LASTFREE, TTAB_GCLIST, TTAB_SIZEARRAY =
          6, 7, 8, 12, 16, 20, 24, 28

local ttable = {
  flags = makeGS(TTAB_FLAGS, U8),
  lsizenode = makeGS(TTAB_LSIZENODE, U8),
  metatable = makeGS(TTAB_METATABLE, PTR),
  array = makeGS(TTAB_ARRAY, PTR),
  node = makeGS(TTAB_NODE, PTR),
  lastfree = makeGS(TTAB_LASTFREE, PTR),
  gclist = makeGS(TTAB_GCLIST, PTR),
  sizearray = makeGS(TTAB_SIZEARRAY, U32),
}

local cstring = ffi.typeof "char[?]"

-- Reads a TValue structure at the specified address
function eval_server.readTValue(address)
  local type = tvalue.type(address)
  if type == valueTypes.NIL then
    return nil, type
  elseif type == valueTypes.BOOLEAN then
    return value.boolean(address) ~= 0, type
  elseif type == valueTypes.LIGHTUSERDATA then
    return value.pointer(address), type
  elseif type == valueTypes.NUMBER then
    return value.number(address), type
  elseif type == valueTypes.STRING then
    local gco = value.gco(address)
    local len = tstring.len(gco)
    local buffer = cstring(len)
    local strbufferAddress = tstring.address(gco)
    for i=0, len-1 do
      buffer[i] = dolphin.memory.readU8(strbufferAddress + i)
    end
    return ffi.string(buffer, len), type
  else
    return value.pointer(address), type
  end
end

function eval_server.overwriteTValue(address, val, typ)
  -- Inlined types can override other inline types
  -- Otherwise, types need to match
  local ltype = type(val)

  if ltype == "nil" then
    tvalue.type(address, valueTypes.NIL)
  elseif ltype == "boolean" then
    tvalue.type(address, valueTypes.BOOLEAN)
    value.boolean(address, val and 1 or 0)
  elseif ltype == "lightuserdata" then
    tvalue.type(address, valueTypes.LIGHTUSERDATA)
    value.pointer(address, val)
  elseif ltype == "number" then
    tvalue.type(address, valueTypes.NUMBER)
    value.number(address, val)
  else
    -- TODO: Handle everything else
    error "Cannot write"
  end
end

function eval_server.findTableEntry(address, i)
  local arraySize = ttable.sizearray(address)

  if i < arraySize then
    -- Read array
    local arrayAddress = ttable.array(address)
    while i < arraySize do
      local valueAddress = arrayAddress + (i * SIZEOF_TV)
      local valueType = tvalue.type(valueAddress)
      if valueType ~= valueTypes.NIL then
        return i, nil, valueAddress
      end
      i = i+1
    end
  end

  local nodeSize = bit.lshift(1, ttable.lsizenode(address))

  i = i-arraySize
  if i < nodeSize then
    local nodeAddress = ttable.node(address)
    while i < nodeSize do
      local currentNodeAddress = nodeAddress + (i * SIZEOF_NODE)
      local valueAddress = node.val(currentNodeAddress)
      local valueType = tvalue.type(valueAddress)
      if valueType ~= valueTypes.NIL then
        return i, node.key(currentNodeAddress), valueAddress
      end
      i = i+1
    end
  end

  return nil
end

function eval_server.readTable(address, i)
  local ni, keyAddress, valueAddress = eval_server.findTableEntry(address, i)

  if not ni then return end

  local value, valueType = eval_server.readTValue(valueAddress)

  if not keyAddress then
    return ni, valueTypes.NUMBER, ni+1, value, valueType
  end

  local key, keyType = eval_server.readTValue(keyAddress)

  return ni, key, keyType, value, valueType
end

function eval_server.overwriteTableValue(address, i, value)
  local ni, keyAddress, valueAddress = eval_server.findTableEntry(address, i)

  eval_server.overwriteTValue(valueAddress, value)
end

function eval_server.getTable(address, key, keyType)
  local i = 0
  while true do
    local ni, readKey, readKeyType, value, valueType = eval_server.readTable(address, i)

    if not ni then break end

    local keyTypesMatch = false
    if keyType then
      keyTypesMatch = keyType == readKeyType
    end

    if key == readKey then
      return ni, value, valueType
    end
    i = ni+1
  end
end

function eval_server.findTable(address, key, keyType)
  local i = 0
  while true do
    local ni, keyAddress, valueAddress = eval_server.findTableEntry(address, i)

    if not ni then break end

    -- Array entry
    if not keyAddress then
      if key == ni-1 then
        return valueAddress
      end
    end

    local readKey, readKeyType = eval_server.readTValue(keyAddress)

    local keyTypesMatch = false
    if keyType then
      keyTypesMatch = keyType == readKeyType
    end

    if key == readKey then
      return ni, valueAddress
    end
    i = ni+1
  end
end

function eval_server.stringLen(address)
  local gco = value.gco(address)
  local len = tstring.len(gco)
  return len
end

function eval_server.replaceStringData(address, data)
  local gco = value.gco(address)
  local dataAddress = tstring.address(gco)
  for i=1, #data do
    dolphin.memory.writeU8(dataAddress+i-1, string.byte(data, i))
  end
end
