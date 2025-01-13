local ver="0.0"
local sources="/etc/apm-sources.st" --serialized table with sources
local default_source_list="pkg.com" --default source list server

local mnp=require("cmnp")
local shell=require("shell")
local ip=require("ipv2")
local apm=require("apm-lib")
local component=require("component")
local gpu=component.gpu

local function cprint(text,color)
  gpu.setForeground(color)
  print(text)
  gpu.setForeground(0xFFFFFF)
end

--functions
local function help()
  cprint("Apt-like Package Manager",0xFFCC33)
  print("Version "..ver)
  print("About: simple package manager for MCNnet")
  cprint("Usage: apm [command]",0x6699FF)
  print("             install  [pname]")
  print("             remove   [pname]")
  print("             info     [pname]")
  print("             addsrc   [hostname]")
  print("             listsrc")
  print("             rmsrc    [hostname]")
  print("             update")
  print("             upgrade  <pname>")
  cprint("Options:",0x33CC33)
  print("--t=<int>      Timeout time")
  print("-s             Silent (TODO)")
end



function connection(dest,timeout)
  if not mnp.isConnected() then cprint("You should be connected to network",0xFF0000) return false end
  if timeout then
    if not tonumber(timeout) then cprint("--t should be given a number, defaulting to 10",0xFFCC33) timeout=10 
    else timeout=tonumber(timeout) end
  else timeout=10 end
  local check,to_ip=mnp.checkAvailability(dest)
  if not check then
    cprint("Couldn't connect",0xFF0000)
    return false
  end
  local domain=""
  if mnp.checkHostname(dest) then domain=dest end
  if domain~="" then print("Connecting to "..domain.."("..to_ip..")")
  else print("Connecting to "..to_ip) end
  
end
function install(pname)

end
--main

if not require("filesystem").exists(sources) then
  local file=io.open(sources,"w")
  file:write(require("serialization").serialize({})):close()
end

local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif args[1]=="install" then
  install(args[2])
else help() end
--[[
1. try packages.com 
2. if not - use source list 
if yes - update source list 

]]