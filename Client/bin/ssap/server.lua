local application=".ssap_application_template" --example
local ssap=require("ssap")
if not ssap.serverConnectionManager(application) then
    print("An error occured and server was stopped")
end