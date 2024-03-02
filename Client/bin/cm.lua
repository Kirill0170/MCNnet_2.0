--MNP CONNECTION MANAGER for client
local ver="INDEV 0.1"
local mnp=require("cmnp")
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
  cprint("Usage: cm [options] <action> ",0x6699FF)
  print("search - search for networks")
  print("status - current connection status")
  print("disconnect - disconnect from network ")
  cprint("Options:",0x33CC33)
  print("-s             Silence logs")
  print("-p             Print logs")
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
  elseif str<200 then color=0xFFFF33
  elseif str<300 then color=0xFFCC33
  else color=0xFF0000 end
  term.write(str1)
  gpu.setForeground(color)
  term.write(" "..str2.."\n")
  gpu.setForeground(0xFFFFFF)
end

local function search(s,p)
  if p==true then mnp.toggleLog(true)
  elseif s==true then mnp.toggleLog(false) end
  log("Opening ports..")
  mnp.openPorts()
  log("Searching for networks...")
  os.setenv("this_ip","0000:0000")
  local rsi=mnp.networkSearch() --res[netname]={from,dist}
  if not next(rsi) then cprint("No networks found",0xFFCC33)
  else
    print("№ | Network name | distance")
    counter=1
    choice={} --choice[num]={{from,dist},netname}
    for name, info in pairs(rsi) do
      printDist(tostring(counter).." | "..name,info[2])
      choice[counter]={rsi[name],name}
      counter=counter+1
    end
    print("------------------------------")
    print("Select network to connect or 'q' to exit")
    local exit=false
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
    mnp.networkConnectByName(choice[selected][1][1],choice[selected][2])
  end
end

local function disconnect()
  mnp.disconnect()
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif args[1]=="disconnect" then disconnect()
elseif args[1]=="status" then status()
elseif args[1]=="search" then search(ops["s"],ops["p"])
else help() end 