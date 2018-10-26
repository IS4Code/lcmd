--lcmd 1.0 by IllidanS4
--Made for YALP v0.2

local interop = require "interop"
local timer = require "timer"
local remote = require "remote"

local debug = debug
_G.debug = nil
local native = interop.native
local SendClientMessage = native.SendClientMessage
local SendClientMessageToAll = native.SendClientMessageToAll

local cached = {}

local cmdenv = {}

cmdenv.interop = interop
cmdenv.timer = timer
cmdenv.remote = remote
cmdenv.wait = timer.wait

local function SendClientMessageToAllLines(color, msg)
  for line in string.gmatch(msg, "[^\n]*") do
     SendClientMessageToAll(color, string.sub(line, 1, 144))
  end
end

function cmdenv.print(...)
  local t = table.pack(...)
  local out = {}
  
  for i = 1, t.n do
    if i ~= 1 then
      table.insert(out, "\t")
    end
    table.insert(out, tostring(t[i]))
  end
  SendClientMessageToAllLines(0xFFFFFFFF, table.concat(out))
end

setmetatable(cmdenv, {
  __index = function(self, idx)
    return _G[idx] or interop[idx] or native[idx]
  end
})

local commands = {}

function commands.lua(playerid, params)
  if not params or #params == 0 then
    SendClientMessage(playerid, -1, "Usage: /lua [code]")
    return true
  end
  cmdenv.player = playerid
  
  local chunk = params
  if cached[playerid] then
    chunk = cached[playerid].."\n"..chunk
    cached[playerid] = nil
  end
  
  local function loader(chunk)
    return load(chunk, "=", "t", cmdenv)
  end
  
  local function trycache(chunk, returned)
    local func, err = loader(chunk)
    if not func then
      err = tostring(err)
      if err:find("near <eof>") then
        if err:find("unexpected symbol near <eof>") then
          SendClientMessageToAllLines(0xA0A0A0FF, params.." {FFFFFF}(?)")
        else
          local match = err:match(": (.*) near <eof>")
          if match then
            if not returned and match == "syntax error" then
              func = trycache("return "..chunk, true)
              if func then
                return func, err
              end
            end
            SendClientMessageToAllLines(0xA0A0A0FF, params.." {FFFFFF}("..match..")")
          else
            SendClientMessageToAllLines(0xA0A0A0FF, params.." {FFFFFF}(...)")
          end
        end
        cached[playerid] = chunk
        return true
      elseif not returned then
        func = trycache("return "..chunk, true)
      end
    end
    return func, err
  end
  
  local func, err = trycache(chunk)
  
  if func == true then
    return true
  end
  
  if func then
    SendClientMessageToAllLines(0xA0A0A0FF, params)
    
    func = loader("return "..chunk) or func
    
    local result = table.pack(async(timer.parallel, 256, pcall, func))
    
    for i = 2, result.n do
      SendClientMessageToAllLines(0xFFFFFFFF, tostring(result[i]))
    end
  else
    SendClientMessageToAll(0xA0A0A0FF, params)
    SendClientMessageToAllLines(0xFFFFFFFF, err)
  end
  return true
end

commands.l = commands.lua

function interop.public.OnPlayerCommandText(playerid, cmdtext)
  playerid = interop.asinteger(playerid)
  cmdtext = interop.asstring(cmdtext)
  
  local ret
  cmdtext:gsub("^/([^ ]+) ?(.*)$", function(cmd, params)
    local handler = commands[string.lower(cmd)]
    if handler then
      ret = handler(playerid, params)
    end
  end)
  return ret
end

function interop.public.OnPlayerConnect(playerid)
  playerid = interop.asinteger(playerid)
  
  cached[playerid] = nil
end

return {
  commands = commands,
  cmdenv = cmdenv
}
