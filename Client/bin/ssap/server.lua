local application="/lib/.ssap_application_template.lua" --example
local ssap=require("ssap")
if not ssap.serverConnectionManager(application) then
    print("An error occured and server was stopped")
end