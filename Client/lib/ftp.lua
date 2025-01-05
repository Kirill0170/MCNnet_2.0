local mnp=require("cmnp")
local ip=require("ipv2")
local ser=require("serialization")
local version="1.4.3"
local ftp={}
ftp.maxPacketLen=2048
function ftp.ver() return version end
function ftp.checkData(data,filePacket)
  if type(data)~="table" then return false end
  if type(data[1])~="string" then return false end
  if type(data[2])~="table" or type(data[3])~="table" then return false end
  if filePacket then
    if not tonumber(data[2]["packetNum"]) then return false end
    if not data[2]["filename"] then return false end
  end
  return true
end
function ftp.connection(to_ip)
  if not ip.isIPv2(to_ip) then return false end
  if not mnp.isConnected() then return false end
  mnp.send(to_ip,"ftp",{"init",{},{}},true)
  local rdata=mnp.receive(to_ip,"ftp",15)
  if not rdata or type(rdata)~="table" then mnp.log("FTP","Connection timeouted!",1) return false end
  if not ftp.checkData(rdata) then mnp.log("FTP","Invalid packet!",1) return false end
  if rdata[1]=="init" then
    if rdata[3][1]=="OK" then os.setenv("ftp_ip",to_ip) return true
    else mnp.log("FTP","Server dropped connection!",1) return false end
  else mnp.log("FTP","Packet type is not init! "..rdata[1],1) return false end
end
function ftp.endConnection(to_ip)
  if not ip.isIPv2(to_ip) then return false end
  mnp.send(to_ip,"ftp",{"end",{},{}})
  os.setenv("ftp_ip",nil)
end
function ftp.checkIntegrity(transmissionSize,filePackets)
  local lostPackets={}
  for i=1,transmissionSize do
    if not filePackets[i] then
      mnp.log("FTP","Lost packet: "..i)
      table.insert(lostPackets,i)
    end
  end
  if lostPackets[1]==nil then lostPackets=nil end
  return lostPackets
end
function ftp.request(to_ip,requestFileName,writeFileName,closeAfter,pretty) --CLIENT
  if not ip.isIPv2(to_ip) then return false,"Invalid ipv2" end
  if not requestFileName then return false,"No file" end
  if not writeFileName then writeFileName=requestFileName end
  mnp.send(to_ip,"ftp",{"get",{},{requestFileName}})
  local success,err=ftp.get(to_ip,requestFileName,writeFileName,pretty)
  if closeAfter then ftp.endConnection(to_ip) end
  return success,err
end
local function padString(input,len)
  input=tostring(input)
  local length = #input
  if length < len then
    local spacesToAdd = len - length
    input = string.rep(" ", spacesToAdd) .. input
  end
  return input
end
local function splitString(inputString)
  local result = {}
  if #inputString > ftp.maxPacketLen then
    for i = 1, #inputString, ftp.maxPacketLen do
      table.insert(result, inputString:sub(i, i + ftp.maxPacketLen - 1))
    end
  else
    table.insert(result, inputString)
  end
  return result
end
local function getPacketLen(packet)
  local len=0
  for i=1,#packet do
    len=len+string.len(packet[i])
  end
  return len
end
function ftp.get(to_ip,requestFileName,writeFileName,pretty)
  if not ip.isIPv2(to_ip) then return false,"Invalid ipv2" end
  if not requestFileName then return false,"No file" end
  if not writeFileName then writeFileName=requestFileName end
  local rdata=mnp.receive(to_ip,"ftp",30)
  if rdata then
    if rdata[1]=="transmissionBegin" then
      local y=0
      local start_time=0
      local total_size=0
      if pretty then
        print(" Time  %Comp  Packets  Size")
        --    | 00:00  100%  100/100  1024
        _,y=require("term").getCursor()
        start_time=require("computer").uptime()
      end
      local transmissionSize=rdata[2]["packets"]
      local filePackets={}
      local timeouts=0
      for i=1,transmissionSize do
        local pdata=mnp.receive(to_ip,"ftp",15)
        if not pdata then
          timeouts=timeouts+1
          if timeouts==5 then
            mnp.log("FTP","Server timeouted!",1) return false,"timeout"
          end
        elseif not ftp.checkData(pdata,true) then mnp.log("FTP","Incorrect data packet: "..ser.serialize(pdata),1)
        elseif pdata[1]~="transmissionData" then mnp.log("FTP","Incorrect packet type: "..pdata[1],1)
        else
          filePackets[pdata[2]["packetNum"]]=pdata[3]
          if pretty then
            local term=require("term")
            total_size=total_size+getPacketLen(pdata[3])
            local time=math.floor(require("computer").uptime()-start_time)
            local mins=math.floor(time/60)
            local secs=time%60
            local stime=" "..string.format("%02d:%02d",mins,secs).."  "
            term.setCursor(1,y)
            term.write(stime..padString(math.floor(i/transmissionSize*100),3).."%  "..padString(i.."/"..transmissionSize,7).."  "..total_size)
          end
        end
        if i%20==0 then mnp.send(to_ip,"ftp",{"transmissionNext",{},{}}) end
      end
      if pretty then require("term").write("\n") end
      mnp.log("FTP","Initial transmission end")
      local lostPackets=ftp.checkIntegrity(transmissionSize,filePackets)
      if lostPackets then
        mnp.send(to_ip,"ftp",{"transmissionLost",{},lostPackets})
        for i=1,#lostPackets do
          local pdata=mnp.receive(to_ip,"ftp",5)
          if not ftp.checkData(pdata,true) then mnp.log("FTP","Incorrect data packet: "..ser.serialize(pdata),1)
          elseif pdata[1]~="transmissionData" then mnp.log("FTP","Incorrect packet type: "..pdata[1],1)
          else filePackets[pdata[2]["packetNum"]]=pdata[3] end
        end
        if ftp.checkIntegrity(transmissionSize,filePackets) then
          mnp.log("FTP","Couldn't get file: lostPackets didn't fix!",2)
          return false,"failLostPackets"
        end
      else
        mnp.send(to_ip,"ftp",{"transmissionSuccess",{},{}})
      end
      --process file
      local file=io.open(writeFileName,"wb")
      for l,line in pairs(filePackets) do
        for i=1,#line do
          file:write(line[i])
        end
      end
      filePackets=nil
      file:close()
      return true,writeFileName
    elseif rdata[1]=="transmissionFail" then
      if rdata[3][1]=="No such file" then
        mnp.log("FTP","No such file: "..to_ip..":"..requestFileName,1)
      end
      return false,rdata[3][1]
    elseif rdata[1]=="transmissionDeny" then
      mnp.log("FTP","Transmission denied: "..rdata[3][1],3)
      return false,rdata[3][1]
    else
      return false,"Unknown"
    end
  else mnp.log("FTP","Connection timeouted!",1) return false,"timeout" end
end
function ftp.upload(to_ip,filename,closeAfter)
  if not ip.isIPv2(to_ip) then return false end
  if not filename then return false end
  mnp.send(to_ip,"ftp",{"put",{},{filename}})
  local success=ftp.send(to_ip,filename)
  if closeAfter then ftp.endConnection(to_ip) end
  return success
end
function ftp.send(to_ip,filename)
  if not ip.isIPv2(to_ip) then return false end
  if not filename then return false end
  local file=io.open(filename,"rb")
  if not file then
    mnp.send(to_ip,"ftp",{"transmissionFail",{},{"No such file"}})
    return false
  end
  --Prepare file
  local fileLines={}
  local prev=""
  while prev do
    prev=file:read(ftp.maxPacketLen)
    if prev then table.insert(fileLines,prev) end
  end
  file:close()
  --Pack file to packets
  local packets={}
  local currentPacket={}
  for i=1,#fileLines do
    if getPacketLen(currentPacket)+string.len(fileLines[i])>ftp.maxPacketLen then
      table.insert(packets,currentPacket)
      currentPacket={}
    end
    table.insert(currentPacket,fileLines[i])
  end
  table.insert(packets,currentPacket)
  currentPacket=nil
  fileLines=nil
  --send
  local options={}
  options.packets=#packets
  mnp.send(to_ip,"ftp",{"transmissionBegin",options,{}})
  for i=1,#packets do
    options={}; options.packetNum=i
    options.filename=filename
    mnp.send(to_ip,"ftp",{"transmissionData",options,packets[i]})
    if i%20==0 then
      local ndata=mnp.receive(to_ip,"ftp",15)
      if not ndata then
        mnp.log("FTP","Client timeouted during send",1)
        return false
      else
        if not ndata[1]=="transmissionNext" then
          mnp.log("FTP","Client sent incorrect NEXT packet; stopping",1)
          return false
        end
      end
    end
  end
  --check client status
  local rdata=mnp.receive(to_ip,"ftp",30)
  if not rdata then
    mnp.log("FTP","Client timeouted after transmission",1)
    return false
  elseif not ftp.checkData(rdata) then
    mnp.log("FTP","Invalid packet after transmission",1)
    return false
  else
    if rdata[1]=="transmissionSuccess" then return true
    elseif rdata[1]=="transmissionLost" then
      local lostPackets=rdata[3]
      for i=1,#lostPackets do
        local options={}
        options["packetNum"]=lostPackets[i]
        mnp.send(to_ip,"ftp",{"transmissionData",options,packets[lostPackets[i]]})
      end
      return true --we did everything we could
    else
      return false
    end
  end
end
function ftp.serverConnectionAwait(to_ip,timeoutTime)
  if not ip.isIPv2(to_ip) then return false end
  if not tonumber(timeoutTime) then timeoutTime=60
  else timeoutTime=tonumber(timeoutTime) end
  local rdata=mnp.receive(to_ip,"ftp",timeoutTime)
  if not rdata or type(rdata)~="table" then return false end
  if not ftp.checkData(rdata) then mnp.log("FTP","Invalid packet!",1) return false end
  if rdata[1]=="init" then
    mnp.send(to_ip,"ftp",{"init",{},{"OK"}})
    return true
  else mnp.log("FTP","Packet type is not init! "..rdata[1],1) return false end
end
function ftp.serverConnectionInit(to_ip,rdata)
  if not ip.isIPv2(to_ip) then return false end
  if not rdata or type(rdata)~="table" then return false end
  if not ftp.checkData(rdata) then mnp.log("FTP","Invalid packet!",1) return false end
  if rdata[1]=="init" then
    mnp.send(to_ip,"ftp",{"init",{},{"OK"}})
    return true
  else mnp.log("FTP","Packet type is not init! "..rdata[1],1) return false end
end
function ftp.serverConnection(to_ip,only)
  mnp.log("FTP","Server connection with "..to_ip)
  while true do
    local rdata=mnp.receive(to_ip,"ftp",30)
    if ftp.checkData(rdata) then
      if rdata[1]=="get" then
        if type(only)=="string" then
          if rdata[3][1]~=only then
            --forbidden
            mnp.send(to_ip,"ftp",{"transmissionDeny",{},{"Forbidden file: "..tostring(rdata[3][1]).."; expected: "..only}})
            return false
          end
        end
        ftp.send(to_ip,rdata[3][1])
        mnp.log("FTP","Sent file: "..rdata[3][1].." to "..to_ip)
      elseif rdata[1]=="put" then
        local filename=rdata[3][1]
        ftp.get(to_ip,filename,filename)
        mnp.log("FTP","Downloaded file: "..filename.." from "..to_ip)
      elseif rdata[1]=="end" then
        mnp.log("FTP","Ended connection with "..to_ip)
        return
      else
        mnp.log("FTP","Dunno: "..rdata[1])
      end
    else
      mnp.log("FTP",to_ip.." timeouted")
      return
    end
  end
end
return ftp
--[[
  packet: "type",{options},{data}
  1. connection init
  2. send/request files 
]]
--TODO: CHECK ONE-LINE>MAXPACKETSIZE