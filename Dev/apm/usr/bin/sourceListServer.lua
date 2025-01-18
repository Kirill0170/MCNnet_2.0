--server with list of sources
local sources={
  package1={"example.com","1.0"}
}
local domain=""
local cmnp=require("cmnp")
if not cmnp.isConnected() then error("Not connected!") end
if domain~="" then cmnp.setDomain(domain) end
require("thread").create(cmnp.mncp.c2cPingService):detach()
while true do
  local rdata,np=cmnp.receive("broadcast","apm",10,true)
  if not rdata or not np then
    cmnp.log("SERVER","No np or rdata!",1)
  else
    cmnp.log("SERVER","Data!")
    local from_ip=np["route"][0]
    if rdata[1]=="get-list" then
      cmnp.send(from_ip,"apm",{"default-list",sources})
    end
  end
end