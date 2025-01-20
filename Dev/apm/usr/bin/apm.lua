local ver = "1.0"
local sources_file = "/etc/apm-sources.st" --serialized table with sources
local default_source_server = "pkg.com" --default source list server
local sources = {} --sources[pname]={server,latest_version, installed_version,info,size,files}
local mnp = require("cmnp")
local shell = require("shell")
local term=require("term")
local apm = require("apm-lib")
local component = require("component")
local computer=require("computer")
local ser = require("serialization")
local fs=require("filesystem")
local gpu = component.gpu

local function cprint(text, color)
  if not color then print(text) return end
	gpu.setForeground(color)
	print(text)
	gpu.setForeground(0xFFFFFF)
end

local function bytesConvert(sizeStr)
	local value, unit = sizeStr:match("(%d+%.?%d*)%s*(%a+)")
	value = tonumber(value)
	if unit == "B" then
		return value
	elseif unit == "KB" then
		return value * 1024
	elseif unit == "MB" then
		return value * 1024 * 1024
	elseif unit == "GB" then	
		return value * 1024 * 1024 * 1024
	else
		error("Unsupported unit: " .. unit)
	end
end

local function fbytes(num)
	local units = {"B", "KB", "MB", "GB", "TB"}
	local unitIndex = 1
	while num >= 1024 and unitIndex < #units do
		num = num / 1024
		unitIndex = unitIndex + 1
	end
	return string.format("%.1f %s", num, units[unitIndex])
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
	print("Lib version "..apm.ver())
	print("About: simple package manager for MCNnet")
	cprint("Usage: apm [command]", 0x6699FF)
print([[             install  [pname]
             remove   [pname]
             info     [pname]
             update
             upgrade  <pname>
             list --<upgradable/installed> 
Source management:
             addsrc   [hostname] [pname]
             rmsrc    [pname]
             listsrc
             fetchsrc
             printsrc]])
	cprint("Options:", 0x33CC33)
	print("--t=<int>      Timeout time")
	print("-s             Silent (TODO)")
	print("-f             Do forcefully")
end

function loadSources()
	local file = io.open(sources_file, "r")
	if not file then
		error("Couldn't open sources file to read!")
	end
	sources = ser.unserialize(file:read("*l"))
	if type(sources) == "table" then
		return true
	else
		sources = {}
		return false
	end
end

function saveSources()
  local file = io.open(sources_file, "w")
	if not file then
		error("Couldn't open sources file to read!")
	end
	file:write(ser.serialize(sources))
  return true
end

function info(pname)
	if not sources[pname] then
		cprint("!!Error: Couldn't locate package " .. pname .. "!", 0xFF0000)
		return false
	end
	local info=sources[pname]
	cprint("Package: "..pname,0x336699)
	cprint("Latest version: "..info[2])
	if info[3] then
		cprint("Installed version: "..tostring(info[3]))
	end
	cprint("Server: "..info[1])
	if not info[4] then info[4]="No description given." end
	cprint("Info: "..tostring(info[4]))
	if not info[5] then info[5]="Unknown" end
	cprint("Size: "..tostring(info[5]))
  if not info[6] then info[6]={"Unknown files"}
	else print("Files:") end
  for _,file in pairs(info[6]) do
    print("  "..file)
  end
end
function fetchDefaultSources()
	if not mnp.isConnected() then
		cprint("!!Error: You should be connected to network!", 0xFF0000)
		return false
	end
  local check, to_ip = mnp.checkAvailability(default_source_server)
	if not check then
		cprint("!!Error: Couldn't connect to default source server!", 0xFF0000)
		return nil
	else
		cprint(">>Connecting to " .. to_ip, 0x6699FF)
		local default_sources = apm.getDefaultSources(to_ip)
    if default_sources then
      cprint(">>Successfully fetched default sources list!",0x33CC33)
      os.sleep(0.2)
      cprint(">>Setting up..",0x6699FF)
      os.sleep(0.2)
      for pname,info in pairs(default_sources) do
        sources[pname]=info
        print("["..info[1].."] "..pname.." "..info[2])
      end
      saveSources()
      cprint(">>Saved",0x33CC33)
    else
      cprint("!!Error: Failed to fetch default sources!",0xFF0000)
      return false
    end
	end
end
function update()
	if not mnp.isConnected() then
		cprint("!!Error: You should be connected to network!", 0xFF0000)
		return false
	end
	cprint(">>Updating package list", 0x6699FF)
  --collect
  cprint(">>Collecting servers..",0x6699FF)
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
        local latest_ver,info,size,files=apm.getInfo(server_ip,pname)
        if not latest_ver then
          cprint("!Error: Couldn't get version for "..pname,0xFF0000)
        elseif sources[pname][2]~=latest_ver then
          cprint(">>New version: "..pname.." "..sources[pname][2].." -> "..latest_ver,0x6699FF)
        else
          cprint(">>Not changed: "..pname.." "..latest_ver)
        end
				sources[pname][2]=latest_ver
				sources[pname][4]=info
				sources[pname][5]=size
				sources[pname][6]=files
      end
    end
  end
	saveSources()
  cprint(">>Completed, took "..ftime(computer.uptime()-start_time),0x33CC33)
end
function install(pname,force)
	if not mnp.isConnected() then
		cprint("!!Error: You should be connected to network!", 0xFF0000)
		return false
	end
  if not force then force=false end
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
	cprint(">>Connecting to " .. to_ip, 0x6699FF)
  local start_time=computer.uptime()
	local success, err = apm.getPackage(to_ip, pname, true,sources[pname][3],force)
	if not success then
		if err == "aborted" then
			cprint("Aborted")
			return
		end
		cprint("!!Error: Couldn't get packet: " .. err, 0xFF0000)
  else
		sources[pname][3]=err
		saveSources()
    cprint(">>Installed successfully! Took "..ftime(computer.uptime()-start_time),0x33CC33)
	end
end
function upgrade(force)
	if not mnp.isConnected() then
		cprint("!!Error: You should be connected to network!", 0xFF0000)
		return false
	end
	cprint(">>Upgrading",0x6699FF)
	update()
	local queue={}
	local total_size=0
	for pname,pinfo in pairs(sources) do
		if (tostring(pinfo[2])~=tostring(pinfo[3]) and pinfo[3]) or (pinfo[3] and force) then
			cprint(">>Updating:"..pname.." "..pinfo[3].." -> "..pinfo[2],0x336699)
			if pinfo[5] then total_size=total_size+bytesConvert(pinfo[5]) end
			if not queue[pinfo[1]] then
				queue[pinfo[1]]={pname}
			else
				table.insert(queue[pinfo[1]],pname)
			end
		end
	end
	--ask
	if total_size==0 then
		cprint(">>Nothing to upgrade",0x33CC33)
		return
	end
	cprint("??Download "..fbytes(total_size).." of packages?",0xFFFF33)
	term.write("[Y/n]: ")
	local choice=io.read()
	if choice =="n" or choice=="N" then
		print("Aborted.")
		return
	end
	local start_time=computer.uptime()
	for server,packages in pairs(queue) do
		--check dest
		local check,server_ip=mnp.checkAvailability(server)
		if check then
			cprint(">>Connecting to " .. server_ip, 0x6699FF)
			for _,pname in pairs(packages) do
				local success, err = apm.getPackage(server_ip, pname, true,sources[pname][3],true)
				if not success then
					if err == "aborted" then
						cprint("Aborted")
						return
					end
					cprint("!Error: Couldn't get packet: " .. err, 0xFF0000)
				else
					sources[pname][3]=err
				end
			end
		else
			cprint("!Error: Server unavailable: "..server,0xFF0000)
		end
	end
	saveSources()
  cprint(">>Upgraded successfully! Took "..ftime(computer.uptime()-start_time),0x33CC33)
end
function list(upgradable,installed)
	for pname,pinfo in pairs(sources) do
		if upgradable then
			if pinfo[2]~=pinfo[3] and pinfo[3] then
				cprint(pname.." "..pinfo[3].." can be upgraded to "..pinfo[2],0xFFCC33)
			end
		elseif installed then
			if pinfo[3] then
				cprint(pname.." "..pinfo[3].." ("..pinfo[2]..")",0x336600)
			end
		else
			if pinfo[3] then
				if pinfo[2]~=pinfo[3] then
					cprint(pname.." "..pinfo[3].." ("..pinfo[2]..")",0xFFCC33)
				else
					cprint(pname.." "..pinfo[3].." ("..pinfo[2]..")",0x336600)
				end
			else
				cprint(pname.." "..pinfo[2],0xCCCCCC)
			end
		end
	end
end
function remove(pname)
	if not sources[pname] then
		cprint("!!Error: No such package: "..pname,0xFF0000)
		return false
	end
	local files=sources[pname][6]
	if not files then
		cprint("!!Error: Unknown files of package "..pname,0xFF0000)
		sources[pname][3]=nil
		return false
	end
	for _,file in pairs(files) do
		cprint("  "..file,0xCCCCCC)
	end
	cprint("??Remove those files?",0xFFFF33)
	term.write("[Y/n]")
	local choice=io.read()
	if choice=="n" or choice=="N" then
		print("Aborted. Let the files live.")
		return
	end
	sources[pname][3]=nil --not installed 
	--remove files
  if not sources[pname][6] then return false end
  cprint(">>Removing "..#sources[pname][6].." files...",0xFFFF33)
  for _,file in pairs(sources[pname][6]) do
    if fs.exists(file) then
      cprint(">>Removing "..file,0xFFFF33)
      fs.remove(file)
    end
  end
  return true
end
function addSource(hostname,pname)
	if not pname or not hostname then return false end
	local check,to_ip=mnp.checkAvailability(hostname)
	if not check then
		cprint("!!Error: Can't connect to server: "..hostname,0xFF0000)
		return false
	end
	local ver,info,size,files=apm.getInfo(to_ip,pname)
	if ver then
		sources[pname]={hostname,ver,nil,info,size,files}
		cprint(">>Added package "..pname,0x33CC33)
		return true
	end
	cprint("!!Error: Couldn't get package info!",0xFF0000)
	return false
end
function removeSource(pname)
	if pname then sources[pname]=nil end
end
--main

if not fs.exists(sources_file) then
	local file = io.open(sources_file, "w")
	if not file then
		error("Couldn't open source file to write: " .. sources_file)
	end
	file:write(ser.serialize({})):close()
end

if not loadSources() then
  cprint("!!Error: Couldn't load sources!", 0xFF0000)
  return false
end

local args, ops = shell.parse(...)
if not args and not ops then
	help()
elseif ops["h"] or ops["help"] then
	help()
elseif args[1]=="install" then install(args[2],ops["f"])
elseif args[1]=="update" then update()
elseif args[1]=="upgrade" then upgrade(ops["f"])
elseif args[1]=="fetchsrc" then fetchDefaultSources()
elseif args[1]=="printsrc" then print(ser.serialize(sources))
elseif args[1]=="info" then info(args[2])
elseif args[1]=="list" then list(ops["upgradable"],ops["installed"])
elseif args[1]=="remove" then remove(args[2])
elseif args[1]=="addsrc" then addSource(args[2],args[3])
elseif args[1]=="rmsrc" then removeSource(args[2])
else
	help()
end
saveSources()
--[[
1. try packages.com 
2. if not - use source list 
if yes - update source list 
list --upgradable
]]
--sources[pname]={server,latest_version, installed_version,info,size,files}