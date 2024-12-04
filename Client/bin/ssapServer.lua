local application="ssap_application_template" --example
local domain=""
local ssap=require("ssap")
local cmnp=require("cmnp")
if not cmnp.isConnected() then error("Not connected!") end
if domain~="" then cmnp.setDomain(domain) end
require("thread").create(cmnp.mncp.c2cPingService):detach()
if not ssap.serverConnectionManager(application) then
    print("Server was stopped")
    cmnp.mncp.stopService()
end