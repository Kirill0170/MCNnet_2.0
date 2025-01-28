--NODE Admin client
local ver="1.1.0"
local mnp=require("cmnp")
local term=require("term")
local shell=require("shell")
local ip=require("ipv2")
local component=require("component")
local modem=component.modem
local netpacket= require("netpacket")
local ser=require("serialization")
local gpu=component.gpu
local node_ip=""
if not node_password then node_password=nil end
local np=nil

local function cprint(text,color)
  gpu.setForeground(color)
  print(text)
  gpu.setForeground(0xFFFFFF)
end

--functions
local function help()
  cprint("Node ADMin",0xFFCC33)
  print("Version "..ver)
  print("About: simple node administration utility")
  print("! Requires network password")
  cprint("Usage: nadm [action] [args]",0x6699FF)
  cprint("Actions: ",0x33cc33)
  print([[
banip [ipv2]  Ban an ip from node(bans netcard UUID)
ban [uuid]    Ban netcard UUID from network
unban [uuid]  Unban netcard UUID from network
list          List connected clients and domain list
]])
  cprint("Options: ",0x33cc33)
  print("-P    Ask password")
  print("Examples:")
  print("nadm banip 12ab:34cd")
  print("nadm list")
end
local function getPassword(force)
  if (not node_password) or force then
    term.write("Net Password: ")
    local new_password=term.read({},false,{},"*")
    term.write("\n")
    new_password=string.sub(new_password,1,#new_password-1)
    node_password=new_password
  end
end
local function status()
  local rdata=mnp.receive(node_ip,"nadm",5)
  if not rdata then
    cprint("Node timeouted!",0xFF0000)
  else
    if rdata[1]=="success" then
      cprint("Operation successful.",0x33cc33)
    else
      cprint("Operation failed: "..tostring(rdata[2]),0xFFCC33)
    end
  end
end
local function ban(uuid)
  if not ip.isUUID(uuid) then cprint("You should give an UUID!",0xFF0000) return false end
  getPassword()
  modem.send(os.getenv("node_uuid"),1002,"nadm",np,ser.serialize({"ban",node_password,uuid}))
  status()
end
local function unban(uuid)
  if not ip.isUUID(uuid) then cprint("You should give an UUID!",0xFF0000) return false end
  getPassword()
  modem.send(os.getenv("node_uuid"),1002,"nadm",np,ser.serialize({"unban",node_password,uuid}))
  status()
end
local function banip(n_ip)
  if not ip.isIPv2(n_ip) then cprint("You should give a valid IPv2!",0xFF0000) return false end
  getPassword()
  if n_ip==os.getenv("this_ip") then
    cprint("You want to ip-ban yourself? [y/N]",0xFFCC33)
    local choice=io.read()
    if choice=="y" or choice=="Y" then
      cprint("Your funeral.",0xFF0000)
    else
      print("Aborted")
      return
    end
  end
  modem.send(os.getenv("node_uuid"),1002,"nadm",np,ser.serialize({"banip",node_password,n_ip}))
  status()
end
local function list()
  getPassword()
  modem.send(os.getenv("node_uuid"),1002,"nadm",np,ser.serialize({"list",node_password}))
  local rdata=mnp.receive(node_ip,"nadm",5)
  if not rdata then
    cprint("Node timeouted!",0xFF0000)
    return
  end
  if rdata[1]~="list" then
    cprint("Couldn't list: "..tostring(rdata[2]),0xFFCC33)
    return
  end
  print("--Node IPs-----------")
  for l_ip,l_uuid in pairs(rdata[2]) do
    local str="Client "
    if ip.isIPv2(l_ip,true) then str="Node   " end
    print(str..l_ip.." "..l_uuid)
  end
  print("--DNS----------------")
  for domain,l_ip in pairs(rdata[3]) do
    print(domain.." - "..l_ip)
  end
end
--main
if not mnp.isConnected() then cprint("You should be connected to network",0xFF0000) return false end
node_ip=string.sub(os.getenv("this_ip"),1,4)..":0000"
np=ser.serialize(netpacket.newPacket())
local args,ops = shell.parse(...)
if ops["P"] then getPassword(true) end

if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif args[1]=="help" then help()
elseif args[1]=="ban" then ban(args[2])
elseif args[1]=="unban" then unban(args[2])
elseif args[1]=="banip" then banip(args[2])
elseif args[1]=="list" then list()
else help() end