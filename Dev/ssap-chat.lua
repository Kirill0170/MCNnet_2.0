--[[
  SSAP APPLICATION

  Your application is down below.
  DO NOT EDIT ANYTHING ELSE, unless you know what you
  are doing.

  api table is yours to use in your application.
  configure your application in CONFIG section.
]]
--CONFIG
local config={}
config["name"]="app" --your application name
config["log"]=true --log stuff

local styles={} -- configure styles here
styles["error"]={} --red text
styles["error"]["fg_color"]="0xFF0000"
styles["reset"]={}
styles["reset"]["bg_color"]="0x000000"
styles["reset"]["fg_color"]="0xFFFFFF"
styles["warn"]={}
styles["warn"]["fg_color"]="0xFFFF33"
styles["msg"]={}
styles["msg"]["fg_color"]="0xCCCCCC"
styles["good"]={}
styles["good"]["fg_color"]="0x33CC33"

--DO NOT EDIT BELOW
local ssap=require("ssap")
local computer=require("computer")
local event=require("event")
--CHAT
local chat={}
chat.users={}
chat.usernames={}
function chat.main()
  while true do
    local id,username,text=event.pullMultiple("chat_msg","chat_stop","chat_join","chat_leave")
    if id=="chat_stop" then break
    else
      local style="msg"
      if id=="chat_msg" then text="<"..username.."> "..text
      elseif id=="chat_join" then
        style="warn"
        text=username.." has joined the chat!"
      else
        style="warn"
        text=username.." has left the chat!"
      end
      local opt=styles[style]
      opt["listener"]=true
      for i=1,#chat.users do
        if chat.usernames[i]~=username then --dont send to the same client
          ssap.send(chat.users[i],{"text",opt,{text}})
        end
      end
    end
  end
  print("end main")
end

local app={}
------------------------
function app.setup() --will be called once during server start
  require("thread").create(chat.main):detach()
  chat.start_time=computer.uptime()
end
function app.shutdown() --will be called when server stops
  computer.pushSignal("chat_stop")
end
function app.main(to_ip) --will be used for each client
  local username
  --functions
  local function stop()
    if config["log"] then print("Shutting down application '"..config["name"].."' with "..to_ip) end
    os.exit()
  end
  local api={}
  function api.exit()
    ssap.disconnect(to_ip)
    computer.pushSignal("chat_leave",username)
    for i=1,#chat.users do
      if chat.users[i]==to_ip then
        table.remove(chat.users,i)
        table.remove(chat.usernames,i)
      end
    end
    return
  end
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
    if type(text)=="string" then text={text} end
    ssap.send(to_ip,{"text",options,text})
  end
  function api.input(timeoutTime,label)
    local result=ssap.server.getInput(to_ip,timeoutTime,label)
    if not result then --handle timeout
      if config["log"] then print("Timeouted during input") end
      api.exit()
    end
    return result
  end
  function api.keyPress(timeoutTime,only)
    local result=ssap.server.getKeyPress(to_ip,timeoutTime,only)
    if not result then --handle timeout
      if config["log"] then print("Timeouted during keypress") end
      ssap.disconnect(to_ip)
      api.exit()
    end
    return result
  end
  function api.clear()
    ssap.send(to_ip,{"clear",{},{}})
  end
  -----EDIT HERE YOUR APPLICATION---------
  if config["log"] then print("Application started") end
  api.clear()
  api.text("SSAP simpleCHAT")
  while true do
    username=api.input(50,"Username: ")
    --check
    local chk=true
    for i=1,#chat.users do
      if chat.users[i]==username then
        api.text("Username taken!",styles["error"])
        chk=false
      end
    end
    if username=="" then chk=false end
    if chk then break end
  end
  api.text("Welcome, "..username.."!")
  api.text(#chat.users.." other users online!")
  api.text("/ for commands, /? or /help for help")
  api.text("Press any key to write")
  ssap.server.textlisten(to_ip)
  table.insert(chat.users,to_ip)
  table.insert(chat.usernames,username)
  computer.pushSignal("chat_join",username)
  while true do --main loop(You don't want your application to finish, right?)
    api.keyPress(600)
    local str=api.input(600,"> ")
    if not str then return false end
    if string.sub(str,1,1)=="/" then
      if str=="/q" or str=="/exit" then
        api.exit()--or os.exit()
        break
      elseif str=="/?" or str=="/leave" then
        local help_message={
          "Available commands:",
          "/help  /?  /q  /leave",
          "/whoon  /uptime"
        }
        api.text(help_message)
      elseif str=="/whoon" then
        for i=1,#chat.users do
          api.text(" "..chat.usernames[i])
        end
      elseif str=="/uptime" then
        local uptime=math.floor(computer.uptime()-chat.start_time)
        local hours=math.floor(uptime/3600)
        local mins=math.floor((uptime%3600)/60)
        local secs=uptime%60
        local stime=string.format("%02d:%02d:%02d",hours,mins,secs)
        api.text("Uptime: "..stime,styles["good"])
      else
        api.text("Unknown command: "..str,styles["error"])
      end
    else
      computer.pushSignal("chat_msg",username,str)
    end
  end
  -----DO NOT EDIT BELOW------:)---------
end
return app