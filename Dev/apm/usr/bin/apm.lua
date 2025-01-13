local ver="0.0"
local sources_file="/etc/apm-sources.st" --serialized table with sources
local default_source_list="pkg.com" --default source list server
local sources={} --sources[pname]=server

local mnp=require("cmnp")
local shell=require("shell")
local ip=require("ipv2")
local apm=require("apm-lib")
local component=require("component")
local ser=require("serialization")
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

function loadSources()
  local file=io.open(sources_file,"w")
  if not file then
    error("Couldn't open sources file to read!")
  end
  sources=ser.unserialize(file:read("l"))
  if type(sources)==table then return true
  else
    sources={}
    return false
  end
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
function update()
  cprint(">>Updating package list",0x6699FF)
  
  --get sources from default_source_list

end
function install(pname)
  if not mnp.isConnected() then cprint("!!Error: You should be connected to network!",0xFF0000) return false end
  cprint(">>Loading sources from "..sources_file,0xFFFF33)
  if not loadSources() then
    cprint("!!Error: Couldn't load sources!",0xFF0000)
    return false
  end
  if not sources[pname] then
    cprint("!!Error: Couldn't locate package "..pname.."!",0xFF0000)
    return false
  end
  local dest=sources[pname]
  local check,to_ip=mnp.checkAvailability(dest)
  if not check then
    cprint("!!Error: Couldn't connect to "..dest,0xFF0000)
    return false
  end
  cprint(">>Connecting to "..to_ip,0xFFFF33)
  local success=apm.getPacket(to_ip,pname,true)
  if not success then
    cprint("!!Error: Couldn't get packet!",0xFF0000)
  end
end
--main

if not require("filesystem").exists(sources_file) then
  local file=io.open(sources_file,"w")
  if not file then
    error("Couldn't open source file to write: "..sources_file)
  end
  file:write(ser.serialize({})):close()
end

local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif args[1]=="install" then install(args[2])
else help() end
--[[
1. try packages.com 
2. if not - use source list 
if yes - update source list 

]]
