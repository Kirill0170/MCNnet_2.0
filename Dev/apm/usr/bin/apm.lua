local ver = "0.1.0"
local sources_file = "/etc/apm-sources.st" --serialized table with sources
local default_source_server = "pkg.com" --default source list server
local sources = {} --sources[pname]={server,latest_version, installed_version}
local mnp = require("cmnp")
local shell = require("shell")
local ip = require("ipv2")
local apm = require("apm-lib")
local component = require("component")
local computer=require("computer")
local ser = require("serialization")
local gpu = component.gpu

local function cprint(text, color)
	gpu.setForeground(color)
	print(text)
	gpu.setForeground(0xFFFFFF)
end

local function ftime(sec)
  if sec>60 then
    local mins=sec//60
    sec=sec%60
    return mins.."m"..sec.."s"
  else
    return sec.."s"
  end
end

--functions
local function help()
	cprint("Apt-like Package Manager", 0xFFCC33)
	print("Version " .. ver)
	print("About: simple package manager for MCNnet")
	cprint("Usage: apm [command]", 0x6699FF)
	print("             install  [pname]")
	print("             remove   [pname]")
	print("             info     [pname]")
	print("             addsrc   [hostname]")
	print("             listsrc")
	print("             rmsrc    [hostname]")
  print("             fetchsrc")
	print("             update")
	print("             upgrade  <pname>")
	cprint("Options:", 0x33CC33)
	print("--t=<int>      Timeout time")
	print("-s             Silent (TODO)")
end

function loadSources()
	local file = io.open(sources_file, "w")
	if not file then
		error("Couldn't open sources file to read!")
	end
	sources = ser.unserialize(file:read("l"))
	if type(sources) == table then
		return true
	else
		sources = {}
		return false
	end
end

function connection(dest, timeout)
	if not mnp.isConnected() then
		cprint("You should be connected to network", 0xFF0000)
		return false
	end
	if timeout then
		if not tonumber(timeout) then
			cprint("--t should be given a number, defaulting to 10", 0xFFCC33)
			timeout = 10
		else
			timeout = tonumber(timeout)
		end
	else
		timeout = 10
	end
	local check, to_ip = mnp.checkAvailability(dest)
	if not check then
		cprint("Couldn't connect", 0xFF0000)
		return false
	end
	local domain = ""
	if mnp.checkHostname(dest) then
		domain = dest
	end
	if domain ~= "" then
		print("Connecting to " .. domain .. "(" .. to_ip .. ")")
	else
		print("Connecting to " .. to_ip)
	end
end
function fetchDefaultSources()
  local check, to_ip = mnp.checkAvailability(default_source_server)
	if not check then
		cprint("!!Error: Couldn't connect to default source server!", 0xFF0000)
		return nil
	else
		cprint(">>Connecting to " .. to_ip, 0xFFFF33)
		local default_sources = apm.getDefaultSources(to_ip)
    if default_sources then
      cprint(">>Successfully fetched default sources list ("..#default_sources.."entries)",0x33CC33)
      os.sleep(0.2)
      cprint(">>Setting up..",0xFFFF33)
      os.sleep(0.2)
      for i=1,#default_sources do
        sources[default_sources[i][1]]=default_sources[i][2]
        print("["..default_sources[i][2][1]"] "..default_sources[i][1].." "..default_sources[i][2][2])
      end
    else
      cprint("!!Error: Failed to fetch default sources!",0xFF0000)
      return false
    end
	end
end
function update()
	cprint(">>Updating package list", 0x6699FF)
  --collect
  cprint(">>Collecting servers..",0xFFFF33)
  local queue={}
  local len=0
  for pname,pinfo in pairs(sources) do
    if not queue[pinfo[1]] then
      queue[pinfo[1]]={pname}
      len=len+1
    else
      table.insert(queue[pinfo[1]],pname)
    end
  end
  print("--Collected "..len.." servers!")
  local start_time=computer.uptime()
  for server,pnames in pairs(queue) do
    local check,server_ip=mnp.checkAvailability(server)
    if not check then
      cprint("!!Error: Couldn't connect to "..server.."! Skipping all packages from it.",0xFF0000)
    else
      for _,pname in pairs(pnames) do
        local latest_ver=apm.getInfo(server,pname)
        if sources[pname][2]~=latest_ver then
          cprint(">>New version: "..pname.." "..sources[pname][2].." -> "..latest_ver,0x6699FF)
          sources[pname][2]=latest_ver
        else
          cprint(">>Not changed: "..pname.." "..latest_ver)
        end
      end
    end
  end
  print(">>Completed, took "..ftime(computer.uptime()-start_time))
end
function install(pname,force)
	if not mnp.isConnected() then
		cprint("!!Error: You should be connected to network!", 0xFF0000)
		return false
	end
	cprint(">>Loading sources from " .. sources_file, 0xFFFF33)
	if not loadSources() then
		cprint("!!Error: Couldn't load sources!", 0xFF0000)
		return false
	end
	if not sources[pname] then
		cprint("!!Error: Couldn't locate package " .. pname .. "!", 0xFF0000)
		return false
	end
	local dest = sources[pname][1]
	local check, to_ip = mnp.checkAvailability(dest)
	if not check then
		cprint("!!Error: Couldn't connect to " .. dest, 0xFF0000)
		return false
	end
	cprint(">>Connecting to " .. to_ip, 0xFFFF33)
  local start_time=computer.uptime()
	local success, err = apm.getPackage(to_ip, pname, true,sources[pname][3],force)
	if not success then
		if err == "aborted" then
			cprint("Aborted")
			return
		end
		cprint("!!Error: Couldn't get packet: " .. err, 0xFF0000)
  else
    cprint(">>Installed successfully! Took "..ftime(computer.uptime()-start_time),0x33CC33)
	end
end
--main

if not require("filesystem").exists(sources_file) then
	local file = io.open(sources_file, "w")
	if not file then
		error("Couldn't open source file to write: " .. sources_file)
	end
	file:write(ser.serialize({})):close()
end

local args, ops = shell.parse(...)
if not args and not ops then
	help()
elseif ops["h"] or ops["help"] then
	help()
elseif args[1]=="install" then install(args[2],ops["f"])
elseif args[1]=="update" then update()
elseif args[1]=="fetchsrc" then fetchDefaultSources()
else
	help()
end
--[[
1. try packages.com 
2. if not - use source list 
if yes - update source list 

]]
