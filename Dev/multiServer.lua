--Headless FTP + SSAP server
local domain=""
local application="ssap_application_template" --example

local ftp=require("ftp")
local cmnp=require("cmnp")
local ssap=require("ssap")
local thread=require("thread")
local event=require("event")
local ser=require("serialization")
local computer=require("computer")
if not cmnp.isConnected() then error("Not connected!") end
if domain~="" then cmnp.setDomain(domain) end
require("thread").create(cmnp.mncp.c2cPingService):detach()
function ftpServ()
  print("Started FTP server!")
  --start listener
  thread.create(cmnp.listen,"broadcast","ftp","ftpserver_stop","ftpserver_data"):detach()
  local run=true
  while run do
    local id,data,from_ip=event.pullMultiple("interrupted","ftpserver_data")
    if id=="interrupted" then run=false
    elseif id=="ftpserver_data" then
      data=ser.unserialize(data)
      if data then
        if data[1]=="init" then
          if ftp.serverConnectionInit(from_ip,data) then
            thread.create(ftp.serverConnection,from_ip):detach()
          end
        end
      end
    end
  end
  computer.pushSignal("ftpserver_stop")
  cmnp.mncp.stopService()
  print("Servers stopped")
end
function ssapServ()
  print("Started SSAP server!")
  ssap.serverConnectionManager(application)
end

print("Starting FTP+SSAP servers")
thread.create(ftpServ):detach()
thread.create(ssapServ):detach()