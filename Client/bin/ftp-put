local ver="1.2"
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
  cprint("FTP-PUT",0xFFCC33)
  print("Version "..ver)
  print("FTP version: "..ftp.ver())
  print("About: simple FTP put file")
  cprint("Usage: ftp-put server_ip/hostname file-to-upload",0x6699FF)
  print("Examples:")
  print("ftp-put 12ab:34cd /home/file.txt")
  print("ftp-put example.com /home/file.txt")
end

local function connection(to_ip,filename)
  if not mnp.isConnected() then cprint("You should be connected to network",0xFF0000) return false end
  if not filename then cprint("What file to get?",0xFF0000) return false end
  --check destination
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
  --main
  if not ftp.connection(to_ip) then
    cprint("Couldn't connect to "..to_ip,0xFF0000)
  else
    local success,err=ftp.upload(to_ip,filename,true)
    if not success then
      cprint("Couldn't upload file",0xFF0000)
    else
      print("File uploaded")
    end
  end
end
--main
local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif ip.isIPv2(args[1]) or mnp.checkHostname(args[1]) then connection(args[1],args[2])
else help() end