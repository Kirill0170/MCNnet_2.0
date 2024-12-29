local ver="1.5.3"
local ssap=require("ssap")
local mnp=require("cmnp")
local shell=require("shell")
local ip=require("ipv2")
local component=require("component")
local gpu=component.gpu

local function cprint(text,color)
  gpu.setForeground(color)
  print(text)
  gpu.setForeground(0xFFFFFF)
end

--functions
local function help()
  cprint("SSAP client connection",0xFFCC33)
  print("Version "..ver)
  print("SSAP version: "..ssap.ver())
  print("About: simple SSAP conenction client")
  cprint("Usage: client <options> server_ip",0x6699FF)
  cprint("Options:",0x33CC33)
  print("--t=<int>      Timeout time")
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
  else print("Connectiong to "..to_ip) end
  if not ssap.client.connect(to_ip,timeout) then
    cprint("Couldn't connect!",0xFF0000)
  else
    local rcode=ssap.client.connection(to_ip,timeout)
    if rcode==0 then
      print("Closed connection to "..to_ip)
    elseif rcode==1 then
      cprint("Timeouted!",0xFFFF33)
    elseif rcode==2 then
      cprint("Client-side timeout/error",0xFFCC33)
    elseif rcode==3 then
      cprint("FTP error!",0xFFCC33)
    else
      print("Unknown return code!",rcode)
    end
  end
end
local function setDownloadHome(new)
  if ssap.setDownloadRoot(new) then
    print("Success")
  else
    cprint("Couldn't set download root to "..new,0xFF0000)
  end
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif args[1]=="setdownloadhome" then setDownloadHome(args[2])
elseif ip.isIPv2(args[1]) or mnp.checkHostname(args[1]) then connection(args[1],ops["t"])
else help() end
--TODO: VERSION CHECKING