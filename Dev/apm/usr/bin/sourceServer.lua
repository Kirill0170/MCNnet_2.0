--Source server
local packageDir="/etc/packages/" --packages directory
local domain=""
local apm=require("apm-lib")
local cmnp=require("cmnp")
if not cmnp.isConnected() then error("Not connected!") end
if domain~="" then cmnp.setDomain(domain) end
require("thread").create(cmnp.mncp.c2cPingService):detach()
if not apm.server(packageDir) then
  print("apm server was stopped!")
  cmnp.mncp.stopService()
  os.sleep(0.2)
end