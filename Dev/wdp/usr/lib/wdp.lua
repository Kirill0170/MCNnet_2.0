local ver="0.6"
local shouldCheckTDFver=false
local mnp=require("cmnp")
local tdf=require("tdf")
local ftp=require("ftp")
local event=require("event")
local ser=require("serialization")
local fs=require("filesystem")
local wdp={}
function wdp.ver() return ver end
function wdp.setCheckTDF(val)
  if type(val)=="boolean" then
    shouldCheckTDFver=val
    return true
  end
  return false
end
function wdp.isSubdir(allowedDir,givenDir)
  local normalizedRoot = allowedDir:gsub("/+$", "")
  local normalizedGivenDir = givenDir:gsub("/+$", "")
  if normalizedGivenDir:sub(1, #normalizedRoot) == normalizedRoot then
    return true
  end
  return false
end
function wdp.resolve(url)
  if not url then return nil,nil end
  local hostname,filename=url:match("([^/]+)/(.+)")
  return hostname,filename
end
function wdp.get(url,saveAs)
  local dest,filename=wdp.resolve(url)
  if not dest or not filename then return false,"INVALID_URL" end
  local success,to_ip=mnp.checkAvailability(dest)
  if not success then return false,"MNP_CONNECTION_FAIL" end
  mnp.send(to_ip,"wdp",{"get",filename})
  local rdata=mnp.receive(to_ip,"wdp",30)
  if not rdata then return false,"MNP_CONNECTION_TIMEOUT" end
  if rdata[1]~=100 then
    return false,tostring(rdata[1])..": "..rdata[2]
  end
  if not ftp.connection(to_ip) then return false,"FTP_CONNECTION_FAIL" end
  local downloadName=saveAs or os.tmpname()
  local success,err=ftp.request(to_ip,filename,downloadName,true,false)
  if not success then return false,"FTP_GET_FAIL:"..tostring(err) end
  local tfile=tdf.readFile(downloadName)
  if not tfile then return false,"TDF_READ_FAIL" end
  if shouldCheckTDFver then
    if tfile.config.ver~=tdf.ver() then return false,"TDF_DIFF_VER" end
  end
  return true,tfile
end
function wdp.send(to_ip,filename)--add file check
  local check=filename
  if string.sub(filename,1,1)~="/" then
    check=fs.concat(require("shell").getWorkingDirectory(),filename)
  end
  if not fs.exists(check) or fs.isDirectory(check) then
    mnp.send(to_ip,"wdp",{201,"Not Found or Directory"})
    mnp.log("WDP","Failed sending "..filename.." to "..to_ip..": Not found or directory",1)
    mnp.log("WDP","Disconnecting "..to_ip)
    return false
  end
  if not tdf.util.isTDF(filename) then
    mnp.send(to_ip,"wdp",{202,"Not TDF"})
    mnp.log("WDP","Failed sending "..filename.." to "..to_ip..": Invalid file!",1)
    mnp.log("WDP","Disconnecting "..to_ip)
    return false
  end
  mnp.send(to_ip,"wdp",{100,"OK"})
  if not ftp.serverConnectionAwait(to_ip,30) then
    mnp.log("WDP","FTP connection with "..to_ip.." timeouted!",1)
    mnp.log("WDP","Disconnecting "..to_ip)
    return false
  end
  ftp.serverConnection(to_ip,filename)
  mnp.log("WDP","Disconnecting "..to_ip)
  return true
end
function wdp.server(allowedDirectory)
  if allowedDirectory=="" then allowedDirectory=nil end
  mnp.log("WDP","Starting webserver")
  if allowedDirectory then mnp.log("WDP","Allowed directory: "..allowedDirectory) end
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
        if allowedDirectory then
          local check=rdata[2]
          if string.sub(check,1,1)~="/" then
            check=fs.concat(require("shell").getWorkingDirectory(),rdata[2])
          end
          if not wdp.isSubdir(allowedDirectory,check) then
            mnp.log("WDP","Forbidden file: "..check,1)
            mnp.send(from_ip,"wdp",{203,"Forbidden"})
            mnp.log("WDP","Disconnecting "..from_ip)
          else
            mnp.log("WDP","Sending "..rdata[2].." to "..from_ip)
            thread.create(wdp.send,from_ip,rdata[2]):detach()
          end
        else
          mnp.log("WDP","Sending "..rdata[2].." to "..from_ip)
          thread.create(wdp.send,from_ip,rdata[2]):detach()
        end
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