local mnp=require("cmnp")
local ser=require("serialization")
local mail={}
mail.util={}
function mail.util.checkLogin(str)
  return str:match("^[%w%.]+@[%w%.]+%.[%a]+$") ~= nil
end
function mail.util.splitLogin(str)
  local at=str:find("@")
  local dot=str:find(".",at)
  return str:sub(1,at-1),str:sub(at+1)
end

Database={}
Database.__index=Database
function Database:load(filename)
  local file=io.open(filename)
  if not file then
    mnp.log("MAIL/DB","Couldn't initialize db: creating new",1)
    local wfile=io.open(filename,"w")
    if not wfile then
      mnp.log("MAIL/DB","Couldn't write to file: "..filename,2)
      return nil
    end
    wfile:write("{}"):close()
    local instance=setmetatable({},Database)
    instance.name="MailDb"
    instance.mailBoxes={}
    instance.nextMailID=1
    return instance
  else
    local instance=ser.unserialize(file:read("*a"))
    if instance then
      mnp.log("MAIL/DB","Read db from "..filename)
      return instance
    else
      mnp.log("MAIL/DB","Couldn't read db file",2)
      return nil
    end
  end
end

MailBox={}
MailBox.__index=MailBox
function MailBox:new(login,passwd)
  local instance=setmetatable({},MailBox)
  instance.login=login
  instance.passwd=passwd
  instance.inbox={}
  instance.outbox={}
  instance.nextMailID=1
  return instance
end
function MailBox:send(subject,to,message)
  local msg=MailMessage:new(self.nextMailID,subject,self.login,to,message)
  self.nextMailID=self.nextMailID+1
  self.outbox[self.nextMailID]=msg
  --check if local
  local at,domain=mail.util.splitLogin(to)
  if domain==mail.util.splitLogin(self.login)[2] then
    self.inbox[self.nextMailID]=msg
  end
end
MailMessage={}
MailMessage.__index=MailMessage
function MailMessage:new(id,subject,from,to,message)
  local instance=setmetatable({},MailMessage)
  instance.id=id
  instance.subject=subject
  instance.from=from
  instance.to=to
  instance.message=message
  return instance
end
