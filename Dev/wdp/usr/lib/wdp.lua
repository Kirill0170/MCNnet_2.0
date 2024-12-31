local ver="0.3.3"
local mnp=require("cmnp")
local tdf=require("tdf")
local ftp=require("ftp")
local term=require("term")
local gpu=require("component").gpu
local event=require("event")
local ser=require("serialization")
local wdp={}
function wdp.ver() return ver end
function wdp.resolve(url)
  if not url then return nil,nil end
  local hostname,filename=url:match("([^/]+)/(.+)")
  return hostname,filename
end
function wdp.printAddressBar(url,x)
  local str="wdp://"..url
  while string.len(str)<x do str=str.." " end
  local prev_x,prev_y=term.getCursor()
  term.setCursor(1,1)
  gpu.setBackground(0xCCCCCC)
  gpu.setForeground(0x000000)
  print(str)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  term.setCursor(prev_x,prev_y)
end
function wdp.get(url,saveAs)
  local dest,filename=wdp.resolve(url)
  if not dest or not filename then return false,"INVALID_URL" end
  local success,to_ip=mnp.checkAvailability(dest)
  if not success then return false,"MNP_CONNECTION_FAIL" end
  mnp.send(to_ip,"wdp",{"get",filename})
  local rdata=mnp.receive(to_ip,"wdp",30)
  if not rdata then return false,"MNP_CONNECTION_TIMEOUT" end
  os.sleep(0.5)
  if not ftp.connection(to_ip) then return false,"FTP_CONNECTION_FAIL" end
  local downloadName=saveAs or os.tmpname()
  local success,err=ftp.request(to_ip,filename,downloadName,true,false)
  if not success then return false,"FTP_GET_FAIL:"..tostring(err) end
  local tfile=tdf.readFile(downloadName)
  if not tfile then return false,"TDF_READ_FAIL" end
  term.clear()
  tfile:print(1)
  os.sleep(0.1)
  wdp.printAddressBar(url.." - "..tfile.config["title"],tfile.config["resolution"][1])
  return true,"OK"
end
function wdp.send(to_ip,filename)
  mnp.send(to_ip,"wdp",{"response"})
  if not ftp.serverConnectionAwait(to_ip,30) then
    mnp.log("WDP","FTP connection with "..to_ip.." timeouted!",1)
    return false
  end
  ftp.serverConnection(to_ip,filename)
  return true
end
function wdp.server()
  mnp.log("WDP","Starting webserver")
  local thread=require("thread")
  local stopEvent="wdpStop"
  local dataEvent="wdpData"
  thread.create(mnp.listen,"broadcast","wdp",stopEvent,dataEvent):detach()
  while true do
    local id,rdata,from_ip=event.pullMultiple(dataEvent,"interrupted")
    if id=="interrupted" then
      require("computer").pushSignal(stopEvent)
      break
    else
      mnp.log("WDP","Client connection with "..from_ip)
      rdata=ser.unserialize(rdata)
      if rdata[1]=="get" then
        mnp.log("WDP","Sending "..rdata[2].." to "..from_ip)
        thread.create(wdp.send,from_ip,rdata[2]):detach()
      end
    end
  end
end
return wdp
--[[
  wdp://
  URL: 12ab:34cd//home/file.txt
  URL: example.com/local.txt
  1. get requiest
  2. init ftp
  3. server -> client ftp
  4. client saves to /tmp
  5. read tdf
]]