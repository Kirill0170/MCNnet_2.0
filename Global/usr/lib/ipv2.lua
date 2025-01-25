--MCnet IPv2 handling
--Modem is required.

--init----------------------
local component=require("component")
if not component.isAvailable("modem") then error("[IP INIT]: No modem present") end
local this_uuid=component.getPrimary("modem")["address"]
local ip_ver="2.5 BETA"
local nips={} --nips[<ip>]=<uuid>
local ip={}
----------------------------
function ip.ver() return ip_ver end

function ip.getParts(g_ip)
  if not g_ip then return nil end
  if not string.find( g_ip,":") then return nil end
  local a=string.sub(g_ip,1,string.find(g_ip,":")-1)
  local b=string.sub(g_ip,string.find(g_ip,":")+1)
  return a,b
end

function ip.isIPv2(g_ip,nodechk)--nodechk for checking if node
  if not g_ip then return false,nil end
  local pt="^%x%x%x%x:%x%x%x%x$"
  local pt2="^%x%x%x%x:0000$"
  local pt3="^:%x%x%x%x$"
  if nodechk then
    if string.match(g_ip,pt2) then return true,g_ip
    else return false end
  end
  local this_ip=os.getenv("this_ip")
  if not this_ip then this_ip="" end
  if string.match(this_ip,pt) then --if connected, check local
    if string.match(g_ip,pt3) then --make ipv2
      local a=ip.getParts(this_ip)
      return true,a..g_ip
    end
  end
  if string.match(g_ip,pt) then return true,g_ip end
  return false
end

function ip.isUUID(g_uuid) --rewrite
  if not g_uuid then return false end
  local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
  if string.match(g_uuid, pattern) then return true
  else return false end
end

function ip.set(g_ip,node)
  if node then
    if ip.isIPv2(g_ip,true) then
      os.setenv("this_ip",g_ip)
      return true
    else return false end
  else
    if ip.isIPv2(g_ip) then
      os.setenv("this_ip",g_ip)
      return true
    else return false end
  end
end
function ip.remove()
  os.setenv("this_ip",nil)
end

---Node IPs (nips)-----------------
function ip.gnip()
  return string.sub(this_uuid,1,4)..":0000"
end

function ip.fromUUID(g_uuid)
  return string.sub(this_uuid,1,4)..":"..string.sub(g_uuid,1,4)
end

function ip.findUUID(g_ip)
  if not ip.isIPv2(g_ip) then return nil end
  for nip,nuuid in pairs(nips) do
    if nip==g_ip then return nuuid end
  end
  return nil
end

function ip.findIP(g_uuid)
  if not ip.isUUID(g_uuid) then return nil end
  for nip,nuuid in pairs(nips) do
    if nuuid==g_uuid then return nip end
  end
  return nil
end

function ip.addStaticUUID(g_uuid,node)
  if not ip.isUUID(g_uuid) then return nil end
  local f_ip=ip.findIP(g_uuid) --check if this ip already exists
  if f_ip~=nil then --overwrite
    nips[f_ip]=g_uuid
    return f_ip
  end
  local n_ip
  if not node then n_ip=ip.fromUUID(g_uuid) --reg
  else n_ip=string.sub(g_uuid,1,4)..":0000" end --node
  nips[n_ip]=g_uuid
  return n_ip
end
function ip.addDynamicUUID(g_uuid)
  if not ip.isUUID(g_uuid) then return nil end
  local random_part=string.sub(require("uuid").next(),1,4)
  local n_ip=string.sub(this_uuid,1,4)..":"..random_part
  nips[n_ip]=g_uuid
  return n_ip
end
function ip.deleteIP(g_ip)
  nips[g_ip]=nil return true
end

function ip.deleteUUID(g_uuid)
  for n_ip,n_uuid in pairs(nips) do
    if n_uuid==g_uuid then
      nips[n_ip]=nil
      return n_ip
    end
  end
  return nil
end

function ip.getNodes(except)
  local res={}
  for n_ip,n_uuid in pairs(nips) do
    if ip.isIPv2(n_ip,true) and n_uuid~=except then
      res[n_ip]=n_uuid
    end
  end
  return res
end

function ip.getAll() return nips end
function ip.removeAll() nips={} end

return ip
