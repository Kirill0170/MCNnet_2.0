local domain=""
local wdp=require("wdp")
local cmnp=require("cmnp")
if not cmnp.isConnected() then error("Not connected!") end
if domain~="" then cmnp.setDomain(domain) end
require("thread").create(cmnp.mncp.c2cPingService):detach()
if not wdp.server() then
  print("Wdp server was stopped!")
  cmnp.mncp.stopService()
  os.sleep(0.2)
end