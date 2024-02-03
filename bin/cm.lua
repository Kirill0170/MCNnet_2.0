--MNP CONNECTION MANAGER with TUI for client
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
  print("connect <attempts> <timeout> - Connect to network")
  print("status         Current network")
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

local function connect(a,t,s,p)
  if p==true then mnp.toggleLog(true)
  elseif s==true then mnp.toggleLog(false) end
  mnp.register(a,t,dolog)
end

--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif args[1]=="connect" then
  connect(args[2],args[3],ops["s"],ops["p"])
elseif args[1]=="status" then status()
else help() end 