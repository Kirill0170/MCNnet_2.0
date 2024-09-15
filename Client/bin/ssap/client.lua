local ver="1.0"
local ssap=require("ssap")
local term=require("term")
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
  print("About: simple SSAP conenction client")
  cprint("Usage: client <options> server_ip",0x6699FF)
  cprint("Options:",0x33CC33)
  print("--t=<int>      Timeout time")
end

function connection(to_ip,timeout)
    if not ssap.clientConnect(to_ip,timeout) then
        print("Exiting")
    end
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif ip.isIPv2(args[1]) then connection(args[1],ops["t"])
else help() end 