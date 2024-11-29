--MNP CONNECTION MANAGER for client
local ver="ALPHA 0.9"
local filename="/usr/.cm_last_netname"
local mnp=require("cmnp")
local ip=require("ipv2")
local term=require("term")
local shell=require("shell")
local component=require("component")
local gpu=component.gpu

local function cprint(text,color)
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
  print("netsearch               search for networks")
  print("connect <name>       connect to network by name; should have connected to this network previously")
  print("                       use 'cm connect' to connect to previous network")
  print("status               current connection status")
  print("disconnect           disconnect from network ")
  print("nping <n> <t>        ping node")
  print("c2cping <n> <t> [ip] Client-to-Client pinging")
  cprint("Options:",0x33CC33)
  print("-s             Silence logs")
  print("-p             Print logs")
  print("--t=<int>      Timeout time(for ping)")
  print("--n=<int>      Number of iterations(for ping & search)")
end

local function status()
  local this_ip=os.getenv("this_ip")
  if not this_ip then
    cprint("Not connected.",0xFF0000)
    return false
  end
  print("This computer's IP is: "..this_ip)
  if this_ip=="" or not require("ipv2").isIPv2(this_ip) then
    cprint("Not an IP - How did this happen?",0xFFCC33)
  elseif this_ip=="0000:0000" then
    cprint("Registration was aborted - try again.",0xFF0000)
  else
    cprint("Ip is valid",0x33CC33)
    local node_uuid=os.getenv("node_uuid")
    if not require("ipv2").isUUID(node_uuid) then
      cprint("Node uuid failure",0xFF0000)
      return false
    end
    if string.match(string.sub(node_uuid,1,4),string.sub(this_ip,1,4)) then
      cprint("Node UUID matches, should be connected (try pinging)",0x33CC33)
      return true
    end
    cprint("Node UUID doesn't match IP - Reconnect required",0xFF0000)
    return false
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

local function savePrevName(name)
  local file=io.open(filename,"w")
  file:write(name)
  file:close()
end
local function loadPrevName()
  local file=io.open(filename,"r")
  if not file then return nil end
  local name=file:read("*a")
  file:close()
  return name
end

local function search(s,p)
  print("Searching for networks...")
  local rsi=mnp.networkSearch(5,true) --res[netname]={from,dist}
  if not next(rsi) then cprint("No networks found",0xFFCC33)
  else
    print("№ | Network name | distance")
    local counter=1
    local choice={} --choice[num]={{from,dist},netname}
    for name, info in pairs(rsi) do
      printDist(tostring(counter).." | "..name,info[2])
      choice[counter]={rsi[name],name}
      counter=counter+1
    end
    print("------------------------------")
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
          cprint("Invalid choice.",0xFF0000)
        end
      else
        cprint("Unknown choice. 'q' to exit.",0xFF0000)
      end
    end
    --connect
    print("Trying to connect to "..choice[selected][2])
    savePrevName(choice[selected][2])
    mnp.networkConnectByName(choice[selected][1][1],choice[selected][2],1)
  end
end

local function connect(name)
  mnp.openPorts()
  if not name then--check previous name
    name=loadPrevName()
    if not name then
      cprint("You haven't connected before. Use 'cm search' to search for networks",0xFFCC33)
      return false
    end
  end
  local address=mnp.getSavedNode(name)
  if not address then 
    cprint("Saved node addresses not found. Use 'cm search' to search for networks",0xFFCC33)
    return false end
  print("Trying to connect to "..name)
  savePrevName(name)
  if mnp.networkConnectByName(address,name) then print("Connected successfully")
  else print("Couldn't connect") end
end

local function disconnect()
  if os.getenv("node_uuid") then mnp.disconnect() end
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
  if n then
    if not tonumber(n) then cprint("--n should be given a number, defaulting to 1.",0xFFCC33) n=1 end
    n=tonumber(n)
  else
    n=1
  end
  if t then
    if not tonumber(t) then cprint("--t should be given a number, defaulting to 10",0xFFCC33) t=10 end
    t=tonumber(t)
  else
    t=10
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
local function c2cping(n,t,to_ip)
  if not mnp.isConnected() then
    cprint("Not connected.",0xFF0000)
    return false
  end
  if n then
    if not tonumber(n) then cprint("--n should be given a number, defaulting to 1.",0xFFCC33) n=1 end
    n=tonumber(n)
  else
    n=1
  end
  if t then
    if not tonumber(t) then cprint("--t should be given a number, defaulting to 10",0xFFCC33) t=10 end
    t=tonumber(t)
  else
    t=10
  end
  if not ip.isIPv2(to_ip) then cprint("IPv2 needed to ping!",0xFF0000) return false end
  if not mnp.getSavedRoute(to_ip) then
    cprint("No route to "..to_ip.." found. searching...",0xFFCC33)
    if not mnp.search(to_ip) then
      cprint("Failed search",0xFFCC33)
      return false
    end
  end
  if not mnp.getSavedRoute(to_ip) then cprint("Couldn't get route for "..to_ip,2) return false end
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
    print(to_ip.." c2c ping for statistics:")
    print("     max: "..max.."s min: "..min.."s avg: "..avg.."s")
  end
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help() end

if ops["p"]==true then mnp.toggleLog(true)
elseif ops["s"]==true then mnp.toggleLog(false) end

if args[1]=="disconnect" then disconnect()
elseif args[1]=="status" then status()
elseif args[1]=="netsearch" then search(ops["s"],ops["p"])
elseif args[1]=="nping" then pingNode(ops["n"],ops["t"])
elseif args[1]=="c2cping" then c2cping(ops["n"],ops["t"],args[2])
elseif args[1]=="connect" then connect(args[2])
else help() end 
--idea: networks: just display netnames to connect to
--todo: clear_routes