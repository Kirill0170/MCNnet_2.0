local mnp=require("cmnp")
local ip=require("ipv2")
local ser=require("serialization")
local version="1.1"
local ftp={}
ftp.maxPacketLen=1024
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
function ftp.request(to_ip,requestFileName,writeFileName,closeAfter)
  if not ip.isIPv2(to_ip) then return false,"Invalid ipv2" end
  if not requestFileName then return false,"No file" end
  if not writeFileName then writeFileName=requestFileName end
  mnp.send(to_ip,"ftp",{"request",{},{requestFileName}})
  local rdata=mnp.receive(to_ip,"ftp",30)
  if rdata then
    if rdata[1]=="transmissionBegin" then
      local transmissionSize=rdata[2]["packets"]
      local filePackets={}
      for i=1,transmissionSize do
        local pdata=mnp.receive(to_ip,"ftp",15)
        if not ftp.checkData(pdata,true) then mnp.log("FTP","Incorrect data packet: "..ser.serialize(pdata),1)
        elseif pdata[1]~="transmissionData" then mnp.log("FTP","Incorrect packet type: "..pdata[1],1)
        else filePackets[pdata[2]["packetNum"]]=pdata[3] end
      end
      mnp.log("FTP","Initial transmission end")
      local lostPackets=ftp.checkIntegrity(transmissionSize,filePackets)
      if lostPackets then
        mnp.send(to_ip,"ftp",{"transmissionLost",{},lostPackets})
        for i=1,#lostPackets do
          local pdata=mnp.receive(to_ip,"ftp",15)
          if not ftp.checkData(pdata,true) then mnp.log("FTP","Incorrect data packet: "..ser.serialize(pdata),1)
          elseif pdata[1]~="transmissionData" then mnp.log("FTP","Incorrect packet type: "..pdata[1],1)
          else filePackets[pdata[2]["packetNum"]]=pdata[3] end
        end
        if ftp.checkIntegrity(transmissionSize,filePackets) then
          mnp.log("FTP","Couldn't get file: lostPackets didn't fix!",2)
          if closeAfter then ftp.endConnection(to_ip) end
          return false,"failLostPackets"
        end
      else
        mnp.send(to_ip,"ftp",{"transmissionSuccess",{},{}})
      end
      if closeAfter then ftp.endConnection(to_ip) end
      --process file
      local file=io.open(writeFileName,"w")
      for l,line in pairs(filePackets) do
        for i=1,#line do
          file:write(line[i].."\n")
        end
      end
      filePackets=nil
      file:close()
      return true
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
function ftp.upload(to_ip,filename)
  if not ip.isIPv2(to_ip) then return false end
  if not filename then return false end
  local file=io.open(filename,"r")
  if not file then
    mnp.send(to_ip,"ftp",{"transmissionFail",{},{"No such file"}})
    return false
  end
  local function getPacketLen(packet)
    local len=0
    for i=1,#packet do
      len=len+string.len(packet[i])
    end
    return len
  end
  --Prepare file
  local fileLines={}
  local prev=""
  while prev do
    prev=file:read("l")
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
  while true do
    local rdata=mnp.receive(to_ip,"ftp",30)
    if ftp.checkData(rdata) then
      if rdata[1]=="request" then
        if type(only)=="string" then
          if rdata[3][1]~=only then
            --forbidden
            mnp.send(to_ip,"ftp",{"transmissionDeny",{},{"Incorrect file: "..tostring(rdata[3][1]).."; expected: "..only}})
            return false
          end
        end
        ftp.upload(to_ip,rdata[3][1])
      elseif rdata[1]=="end" then
        print("debug: ended!")
        return
      else
        mnp.log("FTP","Dunno: "..rdata[1])
      end
    else
      mnp.log("FTP","Timeout")
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