--MCnet IPv2 handling
--Modem is required.
local MODE="NODE" --CLIENT or NODE or SERVER or TNODE
--init----------------------
local component=require("component")
if not component.isAvailable("modem") then error("[IP INIT]: No modem present") end
local this_uuid=component.getPrimary("modem")["address"]
local this_ip=os.getenv("this_ip")
local ip_ver="2.0 EXPERIMENTAL"
print("[IP INIT]: Done")
local nips={} --nips[<ip>]=<uuid>
local ip={}
----------------------------
function ip.ver() return ip_ver end
function ip.setMode(g_mode)
  if g_mode=="NODE" or g_mode=="CLIENT" or g_mode=="SERVER" or g_mode=="TNODE" then
    MODE=g_mode
    return true
  else return false end
end

function ip.isIPv2(g_ip,nodechk)--nodechk for checking if node
  local pt="^%x%x%x%x:%x%x%x%x$"
  local pt2="^%x%x%x%x:0000$"
  if nodechk then
    if string.match(g_ip,pt2) then return true
    else return false end
  end
  if string.match(g_ip,pt) then return true end
  return false
end

function ip.isUUID(g_uuid) --rewrite
  if not g_uuid then return false end
  local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
  if string.match(g_uuid, pattern) then return true
  else return false end
end

function ip.gnip()
  return string.sub(this_uuid,1,4)..":0000"
end

function ip.set(g_ip)
  if MODE=="NODE" or MODE=="TNODE" then
    if ip.isIPv2(g_ip,true) then
      os.setenv("this_ip",g_ip)
      return true
    else return false end
  elseif MODE=="CLIENT" or MODE=="SERVER" then
    if ip.isIPv2(g_ip) then
      os.setenv("this_ip",g_ip)
      return true
    else return false end
  end
end

function ip.getParts(g_ip)
  if not ip.isIPv2(g_ip) then return nil end
  local a=string.sub(g_ip,1,string.find(g_ip,":")-1)
  local b=string.sub(g_ip,string.find(g_ip,":")+1)
  return a,b
end
---Node IPs (nips)-----------------
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

function ip.addUUID(g_uuid,node)
  if not ip.isUUID(g_uuid) then return false end
  local f_ip=ip.findIP(g_uuid) --check if this ip already exists
  if f_ip~=nil then --overwrite
    nips[f_ip]=g_uuid
    return true
  end
  local n_ip
  if not node then n_ip=ip.fromUUID(g_uuid) --reg
  else n_ip=string.sub(g_uuid,1,4)..":0000" end --node
  nips[n_ip]=g_uuid
  return true
end

function ip.deleteUUID(g_uuid)
  nips[g_uuid]=nil return true
end

function ip.getNodes(except)
  local a={}
  local c=0
  for n_ip,n_uuid in pairs(nips) do
    if ip.isIPv2(n_ip,true) and n_ip~=except then
      a[c]=n_uuid c=c+1
    end
  end
  return a
end

function ip.getAll() return nips end

return ip
