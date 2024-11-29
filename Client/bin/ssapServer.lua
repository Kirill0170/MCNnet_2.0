local application="ssap_application_template" --example
local ssap=require("ssap")
local cmnp=require("cmnp")
require("thread").create(cmnp.mncp.c2cPingService):detach()
if not ssap.serverConnectionManager(application) then
    print("Server was stopped")
end