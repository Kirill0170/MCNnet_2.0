---@diagnostic disable: param-type-mismatch, cast-local-type
--[[
  BBS SSAP APPLICATION
]]
--CONFIG
local config={}
config["name"]="BBS" --your application name
config["log"]=true --log stuff
config["ver"]="1.0"
config["sysopPasswd"]="admin" --ADMINISTRATOR PASSWORD
config["sysopMOTD"]={"Welcome to the "..config["name"].." BBS!","Second line"}
config["dbFilename"]="/home/bbs.db"

local styles={} -- configure styles here
styles["error"]={} --red text
styles["error"]["bg_color"]="0x000000"
styles["error"]["fg_color"]="0xFF0000"
styles["reset"]={}
styles["reset"]["bg_color"]="0x000000"
styles["reset"]["fg_color"]="0xFFFFFF"

--DO NOT EDIT BELOW
local ssap=require("ssap")
local ser=require("serialization")
local app={}
app.db={}
app.db["name"]="not initialized db"
---BBS DATABASE----------------------
User={}
User.__index=User
function User:new(name,passwd,admin)
  local instance=setmetatable({},User)
  instance.name=name
  instance.passwd=passwd or ""
  instance.id=User:getNextId()
  instance.admin=admin or false
  instance.readMsg=0 --last read msg(0=all unread)
  return instance
end
function User:getNextId()
  if not User.lastId then User.lastId=0 end
  User.lastId=User.lastId+1
  return User.lastId
end

Message={}
Message.__index=Message
function Message:new(userId,subject,text,replyId)
  local instance=setmetatable({},Message)
  instance.id=Message:getNextId()
  instance.userId=userId
  instance.subject=subject or "No Subject"
  instance.text=text or {""}
  instance.replyId=replyId or 0
  instance.date=os.date()
  return instance
end
function Message:getNextId()
  if not Message.lastId then Message.lastId=0 end
  Message.lastId=Message.lastId+1
  return Message.lastId
end

Database={}
Database.__index=Database
function Database:load()
  local db=setmetatable({},Database)
  local _table=""
  local file=io.open(config["dbFilename"],"r")
  if file then 
    _table=ser.unserialize(file:read("*a"))
    file:close()
  end
  if type(_table)=="table"
  and type(_table["messages"])=="table"
  and type(_table["users"])=="table"
  and _table["name"]=="bbs db" then
    db=setmetatable(_table,Database)
    User.lastId=db.userLastId
    Message.lastId=db.messageLastId
  else
    --initialize database
    print("Initializing new db")
    db.users={}
    db.messages={}
    db.name="bbs db"
    --add guest & user
    local guest=User:new("Guest")
    local admin=User:new("Admin",config.sysopPasswd,true)
    db.users[admin.id]=admin
    db.users[guest.id]=guest
    db.userLastId=User.lastId
    --add MOTD
    local motd=Message:new(admin.id,"MOTD",config.sysopMOTD)
    db.messages[motd.id]=motd
    db.messageLastId=Message.lastId
    --write
    io.open(config.dbFilename,"w"):write(ser.serialize(db)):close()
  end
  return db
end
function Database:addUser(user) self.users[user.id]=user end
function Database:addMessage(msg) self.messages[msg.id]=msg end
function Database:getUser(id) return self.users[id] end
function Database:getMessage(id) return self.messages[id] end
function Database:getUserName(id)
  local user=self.users[id]
  if user then
    if user.name then return user.name
    else return "Unknown User" end
  else return "Deleted User" end
end
function Database:getLastMessages()
  local count=#self.messages
  local start= count>5 and count-4 or 1
  local lastfive={}
  for i=start,count do table.insert(lastfive,self.messages[i]) end
  return lastfive
end
function Database:save()
  local savedata=self
  savedata.userLastId=User.lastId
  savedata.messageLastId=Message.lastId
  io.open(config.dbFilename,"w"):write(ser.serialize(savedata)):close()
end
function Database:getUserByName(name)
  for _,user in pairs(self.users) do
    if user.name==name then return user end
  end
  return nil
end
----------------------------------------
function app.setup() --db
  ssap.log("Started BBS v"..config.ver)
  app.db=Database:load()
end
function app.shutdown()
  app.db:save()
end
function app.main(to_ip)
  ---@class User
  local current_user=nil
  --functions
  local function stop()
    if config["log"] then print("Shutting down application '"..config["name"].."' with "..to_ip) end
    os.exit()
  end
  local api={}
  function api.checkColor(col) --broken
    local pattern = "^0x[0-9A-Fa-f]{6}$"
    if string.match(col, pattern) then return true end
    return false
  end
  function api.text(text,options,position)
    if not text then return false end
    if not options then options={} end
    if position then
      if not tonumber(position[1]) or not tonumber(position[2]) then
        if config["log"] then print("Invalid position for text.") end
        return false end
      options["x"]=tonumber(position[1])
      options["y"]=tonumber(position[2])
    end
    ssap.send(to_ip,{"text",options,{text}})
  end
  function api.input(timeoutTime,label)
    local result=ssap.getInput(to_ip,timeoutTime,label)
    if not result then --handle timeout
      if config["log"] then print("Timeouted during input") end
      ssap.disconnect(to_ip)
      app.shutdown()
    end
    return result
  end
  function api.clear()
    ssap.send(to_ip,{"clear",{},{}})
  end
  function api.exit()
    ssap.disconnect(to_ip)
    --shutdown()
  end
  -----BBS FUNCTIONS----------------
  local bbs={}
  bbs.msg={}
  bbs.util={}
  bbs.admin={}
  function bbs.util.numericChoice(max,prefix,message)
    if not prefix then prefix="" end
    local chosen=false
    while not chosen do
      if type(message)=="table" then 
        for i=1,#message do
          api.text(message[i])
        end
      end
      local choice=api.input(40,prefix)
      if choice:match("^%d+$") ~= nil then
        choice=tonumber(choice)
        if choice>0 and choice<=tonumber(max) then
          return choice
        end
      end
    end
  end
  function bbs.util.yesnoChoice()
    while true do
      local choice=api.input(40,"[Y/n]:")
      if choice=="Y" or choice=="y" then return true end
      if choice=="N" or choice=="n" then return false end
    end
  end
  function bbs.login()
    local login=false
    while not login do
      local username=api.input(20,"Username:")
      if username=="NEW" then
        api.text("Creating new user!")
        local new_username=api.input(20,"New username:")
        if new_username~="" then
          local new_password1=api.input(20,"New password:")
          local new_password2=api.input(20,"Retype password:")
          if new_password1==new_password2 then
            local new_user=User:new(new_username,new_password1)
            app.db:addUser(new_user)
            current_user=new_user
            login=true
          end
        else
          api.text("Name cannot be empty!")
        end
      else
        local pswd=api.input(20,"Password:")
        if app.db:getUserByName(username) then
          if app.db:getUserByName(username).passwd==pswd then
            current_user=app.db:getUserByName(username)
            login=true
          else
            api.text("Incorrect password!",styles["error"])
          end
        else
          api.text("No such user!")
        end
      end
    end
  end
  function bbs.menu()
    local menu_message={
      "-----[BBS MENU]-----",
      "1)Read New Messages("..#app.db.messages-current_user.readMsg..")",
      "2)New Message",
      "3)Read Message",
      "4)Mark All As Read",
      "5)Log Off",
      "--------------------",
      "Enter single digit",
    }
    return bbs.util.numericChoice(6,"[menu]: ",menu_message)
  end
  function bbs.msg.printMessadge(id)
    local msg=app.db:getMessage(id)
    api.text("┌------------------┐")
    api.text("|Subject: "..msg.subject)
    api.text("|From: "..app.db:getUserName(msg.userId))
    api.text("|Date: "..msg.date..";  ID: "..msg.id)
    api.text("├------------------┘")
    for _,line in pairs(msg.text) do
      api.text("|"..line)
    end
    api.text("└------------------┘")
  end
  function bbs.msg.readNew()
    local read=true
    while current_user.readMsg<#app.db.messages and read do
      current_user.readMsg=current_user.readMsg+1
      bbs.msg.printMessadge(current_user.readMsg)
      api.text("1)Next message")
      api.text("2)Exit")
      local choice=bbs.util.numericChoice(2,"[1/2]:")
      if choice==2 then read=false end
    end
    if read then api.text("No new messages.") end
  end
  function bbs.msg.markRead()
    api.text("Are you sure you want to mark all messages as read?")
    if bbs.util.yesnoChoice() then
      current_user.readMsg=#app.db.messages
    end
  end
  function bbs.msg.textEditor()
    local text={}
    api.text("Enter single . to finish")
    local prev=""
    while prev~="." do
      prev=api.input(120,">")
      if prev=="." then break
      else table.insert(text,prev) end
    end
    return text
  end
  function bbs.msg.new()
    api.text("--------------------")
    local new_subject=api.input(30,"Subject: ")
    if new_subject=="" then 
      api.text("Subject cannot be empty!")
      return
    end
    api.text("---Message----------")
    local new_text=bbs.msg.textEditor()
    api.text("Save message?")
    if bbs.util.yesnoChoice() then
      app.db:addMessage(Message:new(current_user.id,new_subject,new_text))
      api.text("Message saved.")
    else api.text("Aborted.") end
  end
  function bbs.msg.read()
    local id=tonumber(api.input(60,"Enter Message ID:"))
    if not id then api.text("[!]ID is a number") return end
    local msg=app.db:getMessage(id)
    if msg then bbs.msg.printMessadge(id)
    else api.text("No message with id: "..id) end
  end
  function bbs.admin.menu()
    local menu_message={
      "---ADMIN-MENU-----",
      "1)List all users",
      "2)Delete user",
      "3)Promote/demote user"
    }
    local choice=bbs.util.numericChoice(3,"ADMIN>: ",menu_message)
    if choice==1 then bbs.admin.listUsers()
    elseif choice==2 then
      local name=api.input(60,"Name: ")
      if app.db:getUserByName(name) then
        app.db.users[app.db:getUserByName(name).id]=nil
      else
        api.text("No such user!")
      end
    elseif choice==3 then
      local name=api.input(60,"Name: ")
      if app.db:getUserByName(name) then
        app.db:getUserByName(name).admin=not app.db:getUserByName(name).admin
      else
        api.text("No such user!")
      end
    end
  end
  function bbs.admin.listUsers()
    for id,user in pairs(app.db.users) do
      local stat="user "
      if user.admin==true then stat="admin" end
      api.text("ID: "..id.." "..stat.." Name: "..user.name)
    end
  end
  -----APPLICATION------------------
  if config["log"] then print("Application started") end
  api.text("SSAP BBS")
  api.text("Welcome!")
  api.text("Enter username, or NEW to create a user, or Guest.")
  bbs.login()
  --user logined
  while true do --main
    local option=bbs.menu()
    if option==1 then bbs.msg.readNew()
    elseif option==2 then bbs.msg.new()
    elseif option==3 then bbs.msg.read()
    elseif option==4 then bbs.msg.markRead()
    elseif option==5 then 
      api.text("Thanks for visiting!")
      api.exit()
      break
    elseif option==6 then
      if current_user.admin==true then
        bbs.admin.menu()
      else
        api.text("You are not an admin!")
      end
    end
  end
  -----DO NOT EDIT BELOW------:)---------
end
return app