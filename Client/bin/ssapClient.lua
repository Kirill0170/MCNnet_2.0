local ver="1.3"
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
  print("SSAP version: "..ssap.getVersion())
  print("About: simple SSAP conenction client")
  cprint("Usage: client <options> server_ip",0x6699FF)
  cprint("Options:",0x33CC33)
  print("--t=<int>      Timeout time")
end

function connection(to_ip,timeout)
  if not mnp.isConnected() then cprint("You should be connected to network",0xFF0000) return false end
  if timeout then
    if not tonumber(timeout) then cprint("--t should be given a number, defaulting to 10",0xFFCC33) timeout=10 
    else timeout=tonumber(timeout) end
  else timeout=10 end
  local domain=""
  if mnp.checkHostname(to_ip) then
    domain=to_ip
    if not mnp.getFromDomain(domain) then
      cprint("No route to "..domain.." found. searching...",0xFFCC33)
      if not mnp.search("",60,domain) then
        cprint("Failed search",0xFFCC33)
        return false
      end
    end
    to_ip=mnp.getFromDomain(domain)[1]
  elseif not mnp.getSavedRoute(to_ip) then
    cprint("No route to "..to_ip.." found. searching...",0xFFCC33)
    if not mnp.search(to_ip) then
      cprint("Failed search",0xFFCC33)
      return false
    end
  end
  if not mnp.getSavedRoute(to_ip) then cprint("Couldn't get route for "..to_ip,2) return false end
  if domain~="" then print("Connecting to "..domain.."("..to_ip..")")
  else print("Connectiong to "..to_ip) end
  if not ssap.clientConnect(to_ip,timeout) then
    print("Exiting")
  else
    ssap.clientConnection(to_ip,timeout)
    print("Closed connection to "..to_ip)
  end
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif ip.isIPv2(args[1]) or mnp.checkHostname(args[1]) then connection(args[1],ops["t"])
else help() end
--TODO: VERSION CHECKING