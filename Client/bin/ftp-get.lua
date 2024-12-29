local ver="1.3"
local mnp=require("cmnp")
local ftp=require("ftp")
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
  cprint("FTP-GET",0xFFCC33)
  print("Version "..ver)
  print("FTP version: "..ftp.ver())
  print("About: simple FTP get file")
  cprint("Usage: ftp-get server_ip/hostname file-to-get file-to-write",0x6699FF)
  print("Examples:")
  print("ftp-get 12ab:34cd /home/file.txt")
  print("ftp-get example.com /etc/about.txt /home/downloaded.txt")
end

local function connection(dest,filename,writefilename)
  if not mnp.isConnected() then cprint("You should be connected to network",0xFF0000) return false end
  if not filename then cprint("What file to get?",0xFF0000) return false end
  if not writefilename then writefilename=filename end
  --check destination
  local check,to_ip=mnp.checkAvailability(dest)
  if not check then
    cprint("Couldn't connect",0xFF0000)
    return false
  end
  --main
  if not ftp.connection(to_ip) then
    cprint("Couldn't connect to "..to_ip,0xFF0000)
  else
    local success,err=ftp.request(to_ip,filename,writefilename,true,true)
    if not success then
      cprint("Couldn't get file: "..tostring(err),0xFF0000)
    else
      print("File saved to "..writefilename)
    end
  end
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif ip.isIPv2(args[1]) or mnp.checkHostname(args[1]) then connection(args[1],args[2],args[3])
else help() end