local ver="0.2"
local wdp=require("wdp")
local mnp=require("cmnp")
local shell=require("shell")
local gpu=require("component").gpu

local function cprint(text,color)
  gpu.setForeground(color)
  print(text)
  gpu.setForeground(0xFFFFFF)
end

--functions
local function help()
  cprint("WDP Browser",0xFFCC33)
  print("Version "..ver)
  print("Web Document Protocol version: "..wdp.ver())
  print("About: simple WDP GET")
  print("Downloads a webpage via FTP and opens it.")
  print("You can set download filename as second argument")
  print("Else, will be saved at /tmp/")
  cprint("Usage: wb <options> [host/file] <saveAs>",0x6699FF)
  print("Examples:")
  print("wb 12ab:34cd/file.tdf")
  print("wb example.com//etc/man.tdf download.tdf")
end

function connection(dest,saveAs)
  if not mnp.isConnected() then cprint("You should be connected to network",0xFF0000) return false end
  if saveAs=="" then saveAs=nil end
  local success,code=wdp.get(dest)
  if not success then
    cprint("Couldn't get page!",0xFF0000)
    cprint("Error code: "..code,0xFF0000)
  end
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif args[1]=="help" then help()
else connection(args[1],args[2]) end
--TODO: VERSION CHECKING