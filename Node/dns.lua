--Domain system for MNP.
--save: t["<ipv2>"]={"<hostname>","<protocol>"}
local filename="hostnames.map"
local ver="1.0 EXPERIMENTAL"
local ser=require("serialization")
local dns={}
function dns.ver() return ver end
function dns.checkHostname(name)
  local pattern = "^%w+%.%w+$"
  return string.match(name, pattern) ~= nil
end
function dns.init(reset) --clears!
  local t={}
  if not reset then
    local file=io.open(filename,"r")
    t=ser.unserialize(file:read("*a"))
    file:close()
  end
  local file2=io.open(filename,"w")
  file2:write(ser.serialize(t))
  file2:close()
end
function dns.add(ip,hostname,protocol)
  if not protocol or not ip or not hostname then return false end
  local file = io.open(filename,"r")
  local t=ser.unserialize(file:read("*a"))
  file:close()
  t[ip]={hostname,protocol}
  local filew =io.open(filename,"w")
  filew:write(ser.serialize(t))
  filew:close()
  return true
end
function dns.lookup(hostname)
  if not hostname then return nil end
  local file = io.open(filename,"r")
  local t=ser.unserialize(file:read("*a"))
  file:close()
  for ip,info in pairs(t) do
    if hostname==info[1] then return ip,info[2] end
  end
  return nil
end
return dns
