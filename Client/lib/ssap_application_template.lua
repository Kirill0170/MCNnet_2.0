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
styles["example"]={} --red text
styles["example"]["bg_color"]="0x000000"
styles["example"]["fg_color"]="0xFF0000"
styles["reset"]={}
styles["reset"]["bg_color"]="0x000000"
styles["reset"]["fg_color"]="0xFFFFFF"

--DO NOT EDIT BELOW
local ssap=require("ssap")
local app={}
------------------------
function app.setup() --will be called once during server start
  --code
end
function app.shutdown() --will be called when server stops
  --code
end
function app.main(to_ip) --will be used for each client
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
  function api.keyPress(timeoutTime,only)
    local result=ssap.getKeyPress(to_ip,timeoutTime,only)
    if not result then --handle timeout
      if config["log"] then print("Timeouted during keypress") end
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
    app.shutdown()
  end

  -----EDIT HERE YOUR APPLICATION---------
  if config["log"] then print("Application started") end
  api.clear()
  api.text("SSAP APP TEMPLATE") --text
  api.text("Hello world!",styles["example"]) -- styled text: use styles
  api.text("test",styles["reset"],{2,2}) --positioned text: {x,y}
  api.text("Press space")
  local a,b=api.keyPress(60,{{-1,57}}) --key press(-1 = any a, 57=space)
  while true do --main loop(You don't want your application to finish, right?)
    local str=api.input(60,"[Enter string]>")
    api.text(str)
    if str=="q" or str=="exit" then
      api.exit()--or os.exit()
      break
    end
  end
  -----DO NOT EDIT BELOW------:)---------
end
return app