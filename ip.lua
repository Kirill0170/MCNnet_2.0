--MCnet IP handling v1.0 EXPERIMENTAL
--Modem is required.
--Don't forget to check file using ip.checkFile(gid,nid)!!!! 
--init----------------------
local component=require("component")
if not component.isAvailable("modem") then error("[IP INIT]: No modem present") end
local this_uuid=component.getPrimary("modem")["address"]
local ip={}
local groupid=-1
local nodeid=-1
----------------------------
function ip.newFile()
  local file=io.open("ips.ipcfg","w")
  if not file then error("[IP NF]: Error creating ips.ipcfg file") end
  file:write("0x000F\n")
  file:write(groupid.."."..nodeid..".0="..this_uuid)
  file:close()
  return "ips.ipcfg"
end
function checkFileIO()
  local file=io.open("ips.ipcfg","r")
  if not file then error("[IP READ]: Error opening ips.ipcfg file, did you make it?") end
  local check=file.read(6)
  local _=file:read(1)
  if check~="0x000F" then error("[IP READ]: ips.ipcfg file check failed") end
  file:close()
end
function ip.isIP(ip_c)
  if not ip_c then return false end
  local pattern = "%d+%.%d+%.%d+"
  if string.match(ip_c, pattern) then --yes
  else return false end
  local numbers = {}
    for number in ip_c:gmatch("%d+") do
        table.insert(numbers, tonumber(number))
    end
  local num1,num2,num3=unpack(numbers)
  if num1<0 or num1>999 then return false end
  if num1<0 or num1>999 then return false end
  if num1<=0 or num1>999 then return false end
  return true
end
function ip.isUUID(str)
  if not str then return false end
  local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
  if string.match(str, pattern) then return true
  else return false end
end
  local function readipline(file2)
    local ipline=""
    while true do
      local c=file2:read(1)
      if c==nil then return ipline 
    elseif c=="|" then local _=file2:read(1) return ipline
      elseif c=="\n" then error("[IP READ]: Found /n when reading ipline")
      else ipline=ipline..c end
    end
  end
--util----------------------
function ip.getLast()
  --prep
  checkFileIO()
  local file=io.open("ips.ipcfg","r")
  file:read(7)
  --main
  while true do
    local ipline=readipline(file)
    local t=file:read(2)
    if t=="" then return ipline end
  end
end
function ip.getFromLine(ipline)
  if not ipline then error("[IP gFL]: Invalid ipline provided") end
  local ip_l=string.sub(ipline,1,string.find(ipline,"="))
  if not ip_l then error("[IP gFL]: Failed getting ip from <"..ipline..">") end
  local uuid=string.sub(ipline,string.find(ipline,"="))
  if not uuid then error("[IP gFL]: Failed getting uuid from <"..ipline..">") end
  return ip_l,uuid
end
function ip.setgn(gid,nid)
  if not tonumber(gid) or not tonumber(nid) then error("[IP SET]: Invalid arguments provided") end
  groupid=tonumber(gid)
  nodeid=tonumber(nid)
end
function ip.getNums(raw_ip)
  if not ip.isIP(raw_ip) then return nil end
  local numbers = {}
    for number in raw_ip:gmatch("%d+") do
        table.insert(numbers, tonumber(number))
    end
    return unpack(numbers)
end
function ip.addIp(ip,uuid)
  --checkfile
  checkFileIO()
  local file=io.open("ips.ipcfg","w")
  file:write("|\n")
  file:write(ip.."="..uuid)
end
--main----------------------
function ip.checkFile(gid,nid) --universal, safe
  if not tonumber(gid) or not tonumber(nid) then error("[ID CHECK]: Invalid arguments") end
  local file=io.open("ips.ipcfg","r")
  if not file then 
    ip.setgn(gid,nid)
    ip.newFile()
  end
  local check=file:read(6)
  if check=="0x000F" then return true
  else return false end
end
function ip.getNewIp(uuid)
  local last_ip,_=ip.getFromLine(ip.getLast())
  if not last_ip then error("[IP NEW]: Could not resolve last ip")  end
  local _,_,i3=ip.getNums(last_ip)
  local new_ip=groupid.."."..nodeid.."."..tonumber(i3)+1
  ip.addIp(new_ip,uuid)
  return new_ip
end
function ip.getIp(uuid)
  if not ip.isUUID(uuid) then return nil end
  checkFileIO()
  local file=io.open("ips.ipcfg")
  file:read(7)
  while true do
    local ipline=readipline(file)
    if not ipline then break end
    local ip_l,uuid_l=ip.getFromLine(ipline)
    if uuid_l==uuid then return ip_l end
  end
  return nil
end
function ip.getUUID(ip_c)
  if not ip.isIP(ip_c) then return nil end
  checkFileIO()
  local file=io.open("ips.ipcfg")
  file:read(7)
  while true do
    local ipline=readipline(file)
    if not ipline then break end
    local ip_l,uuid_l=ip.getFromLine(ipline)
    if ip_l==ip_c then return uuid_l end
  end
  return nil
end
return ip
--[[
ip: groupid:nodeid:clientid
client/server: 1.1.1
node: 1.1.0(only 0)
admin:0.0.0
ips from 1.1.0 - 99.99.999
]]
--[[ipfile
0x000F
1.2.3=eaa43edf-3f7b-4e31-a9eb-0fd3231437d9|\n
1.2.99=eaa43edf-3f7b-4e31-a9eb-0fd3231437d9
]]
