--MNP CONNECTION MANAGER for client
local ver="ALPHA 0.9.13"
local filename="/etc/.cm_last_netuuid"
local mnp=require("cmnp")
local ip=require("ipv2")
local term=require("term")
local shell=require("shell")
local component=require("component")
local gpu=component.gpu

local function cprint(text,color)
  if not color then print(text) end
  gpu.setForeground(color)
  print(text)
  gpu.setForeground(0xFFFFFF)
end

--functions
local function help()
  cprint("MNP Client Connection Manager",0xFFCC33)
  print("Version "..ver)
  cprint("Usage: cm [action] <options>",0x6699FF)
  cprint("Actions:",0x33CC33)
  local help_cmds=[[
ver                    version info
help                   show this message
netsearch (ns)         search for networks
connect <name>         connect to network by name;
                           should have connected to this network previously
                           use 'cm connect' to connect to previous network
status (s)             current connection status
disconnect (d)         disconnect from network
reconnect  (rc)        disconnect & connect
setdomain  (sd)        set domain
nping (np)<n> <t>      ping node
c2cping (ping) [dest]  Client-to-Client pinging
reset                  reset all saved MNP data
  ]]
  print(help_cmds)
  cprint("Options:",0x33CC33)
  print("-s             Silence logs")
  print("-p             Print logs")
  print("--t=<int>      Timeout time(for ping)")
  print("--n=<int>      Number of iterations(for ping & search)")
end
local function versions()
  cprint("MNP Client Connection Manager",0xFFCC33)
  print("Version "..ver)
  mnp.logVersions()
end

local function savePrevAddress(name)
  local file=io.open(filename,"w")
  file:write(name)
  file:close()
end
local function loadPrevAddress()
  local file=io.open(filename,"r")
  if not file then return nil end
  local name=file:read("*a")
  file:close()
  return name
end
local function status()
  local this_ip=os.getenv("this_ip")
  if not this_ip then
    cprint("Not connected.",0xFF0000)
    return false
  end
  print("This computer's IP is: "..this_ip)
  if mnp.isConnected(true) then
    cprint("Connected!",0x33CC33)
    cprint("Network name: "..mnp.getSavedNodeName(loadPrevAddress()),0x33CC33)
  else
    cprint("Not connected.",0xFF0000)
  end
end

local function printDist(str1,str2)
  local color=0xFFFFFF
  if str2<70 then color=0x33CC33
  elseif str2<200 then color=0xFFFF33
  elseif str2<300 then color=0xFFCC33
  else color=0xFF0000 end
  term.write(str1)
  gpu.setForeground(color)
  term.write(" "..str2.."\n")
  gpu.setForeground(0xFFFFFF)
end


local function netsearch(s,p)
  print("Searching for networks...")
  local rsi=mnp.networkSearch(5,true) --res[node ip]={name,from,dist,requirePassword}
  if not next(rsi) then cprint("No networks found",0xFFCC33)
  else
    print("№ |   IPv2    | Network name | distance")
    print("--+-----------+--------------+---------")
    local counter=1
    local choice={} --choice[num]={{name,from,dist,requirePassword},netname,node_ip}
    for node_ip, info in pairs(rsi) do
      local name=info[1]
      printDist(tostring(counter).." | "..node_ip.." | "..name,info[3])
      choice[counter]={rsi[node_ip],name,node_ip}
      counter=counter+1
    end
    print("--+-----------+--------------+---------")
    print("Select network to connect or 'q' to exit")
    local exit=false
    local selected=0
    while not exit do
      term.write(">")
      local input=io.read()
      if input=="q" then return false
      elseif tonumber(input) then
        if tonumber(input)>=1 and tonumber(input)<=counter and choice[tonumber(input)]~=nil then
          selected=tonumber(input)
          exit=true
        else
          cprint("Unknown choice.",0xFF0000)
        end
      else
        cprint("Invalid choice. 'q' to exit.",0xFF0000)
      end
    end
    --connect
    print("Trying to connect to "..choice[selected][2])
    savePrevAddress(choice[selected][1][2])
    if choice[selected][1][4] then
      term.write("Enter network password: ")
      local new_password=term.read({},false,{},"*")
      term.write("\n")
      new_password=string.sub(new_password,1,#new_password-1)
      if mnp.networkConnectByName(choice[selected][1][2],choice[selected][2],new_password) then
        cprint("Connected successfully",0x33cc33)
        mnp.addNodePassword(choice[selected][3],new_password)
      else
        cprint("Incorrect password!",0xFF0000)
      end
    else
      mnp.networkConnectByName(choice[selected][1][2],choice[selected][2],"")
    end
  end
end

local function connect(name,force_dynamic)
  if force_dynamic==nil then
    force_dynamic=false
  end
  mnp.openPorts()
  local address,password,node_ip
  if not name then--check previous name
    address=loadPrevAddress()
    name,password,node_ip=mnp.getSavedNodeName(address)
  else
    address,password,node_ip=mnp.getSavedNode(name)
  end
  if not address then
    cprint("Saved node addresses not found. Use 'cm netsearch' to search for networks",0xFFCC33)
    return false end
  if mnp.isConnected() then mnp.disconnect() end
  print("Trying to connect to "..name.." ("..node_ip..")")
  savePrevAddress(address)
  local check,password_required=mnp.networkConnectByName(address,name,password,force_dynamic)
  if check then cprint("Connected successfully",0x33cc33)
  elseif password_required then
    term.write("Enter network password: ")
    local new_password=term.read({},false,{},"*")
    new_password=string.sub(new_password,1,#new_password-1)
    term.write("\n")
    if mnp.networkConnectByName(address,name,new_password,force_dynamic) then
      cprint("Connected successfully",0x33cc33)
      mnp.addNodePassword(node_ip,new_password)
    else
      cprint("Incorrect password!",0xFF0000)
    end
  else print("Couldn't connect") end
end

local function disconnect()
  if os.getenv("node_uuid") then mnp.disconnect() end
end

local function reconnect()
  disconnect()
  connect()
end
local function calculateStats(array)
  local max = array[1]
  local min = array[1]
  local sum = 0
  for _, value in ipairs(array) do
      if value>max then max=value end
      if value < min then min = value end
      sum=sum+value
  end
  local average = sum / #array
  return max, min, average
end
local function roundTime(value)
  return math.floor(value*100+0.5)/100
end
local function pingNode(n,t)
  if not mnp.isConnected() then
    cprint("Not connected.",0xFF0000)
    return false
  end
  print("Pinging node "..string.sub(os.getenv("node_uuid"),1,4)..":0000")
  if n==1 then
    local time=mnp.mncp.nodePing(tonumber(t))
    if not time then print("Ping timeout.")
    else print("Ping: "..time.."s") end
  else
    local times={}
    for i=1,n do
      local time=mnp.mncp.nodePing(tonumber(t))
      if not time then print(i..")Ping timeout.") times[i]=0
      else time=roundTime(time) print(i..")Ping: "..time.."s") times[i]=time end
    end
    local max,min,avg=calculateStats(times)
    print("Ping statistics:")
    print("     max: "..max.."s min: "..min.."s avg: "..avg.."s")
  end
end
local function c2cping(n,t,dest)
  if not mnp.isConnected() then
    cprint("Not connected.",0xFF0000)
    return false
  end
  local check,to_ip=mnp.checkAvailability(dest)
  if not check then
    cprint("Couldn't find host!",0xFF0000)
    return false
  end
  print("Client-to-Client pinging "..to_ip)
  if n==1 then
    local time=mnp.mncp.c2cPing(to_ip,tonumber(t))
    if not time then print("c2c ping timeout.")
    else print("Ping: "..time.."s") end
  else
    local times={}
    for i=1,n do
      local time=mnp.mncp.c2cPing(to_ip,tonumber(t))
      if not time then print(i..")c2c ping timeout.") times[i]=0
      else time=roundTime(time) print(i..")Ping: "..time.."s") times[i]=time end
    end
    local max,min,avg=calculateStats(times)
    print(to_ip.." c2c ping statistics:")
    print("     max: "..max.."s min: "..min.."s avg: "..avg.."s")
  end
end
local function reset()
  cprint("Are you sure you want to reset MNP? (cannot be undone)",0xFFCC33)
  term.write("[y/N]: ")
  local chk=io.read()
  if chk=="y" or chk=="Y" then
    print("Resetting!")
    disconnect()
    os.remove("/etc/mnp/SavedNetworks.st")
    os.remove("/etc/mnp/SavedRoutes.st")
    os.remove("/etc/mnp/SavedDomains.st")
  end
end
local function setdomain(name)
  if name then
    if mnp.setDomain(name) then
      cprint("Successfully set domain to "..name,0x33cc33)
      return true
    end
  end
  cprint("Couldn't set domain",0xff0000)
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help() end

if ops["p"]==true then mnp.toggleLog(true)
elseif ops["s"]==true then mnp.toggleLog(false) end

if ops["n"] then
  if not tonumber(ops["n"]) then cprint("--n should be given a number, defaulting to 1.",0xFFCC33) ops["n"]=1 end
  ops["n"]=tonumber(ops["n"])
else ops["n"]=1 end
if ops["n"] then
  if not tonumber(ops["n"]) then cprint("--t should be given a number, defaulting to 10",0xFFCC33) ops["n"]=10 end
  ops["n"]=tonumber(ops["n"])
else ops["n"]=10 end

if args[1]=="disconnect" or args[1]=="d" then disconnect()
elseif args[1]=="status" or args[1]=="s" then status()
elseif args[1]=="netsearch" or args[1]=="ns" then netsearch(ops["s"],ops["p"])
elseif args[1]=="nping" or args[1]=="np" then pingNode(ops["n"],ops["t"])
elseif args[1]=="c2cping" or args[1]=="ping" then c2cping(ops["n"],ops["t"],args[2])
elseif args[1]=="connect" or args[1]=="c" then connect(args[2],ops["d"])
elseif args[1]=="reconnect" or args[1]=="rc" then reconnect()
elseif args[1]=="setdomain" or args[1]=="sd" then setdomain(args[2])
elseif args[1]=="reset" then reset()
elseif args[1]=="help" then help()
elseif args[1]=="ver" then versions()
else help() end
--idea: networks: just display netnames to connect to
--todo: clear_routes