--[[
  SSAP APPLICATION

  Your application is application() function.
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
styles["example"]={}
styles["example"]["bg_color"]="0x000000"
styles["example"]["fg_color"]="0xFFFFEE"

local function application() --EDIT HERE
  if config["log"] then print("Application started") end
  while true do --main loop(You don't want your application to finish, right?)
    api.text("SSAP APP TEMPLATE") --text
    api.text("Hello world!",styles["example"]) -- styled text: use styles
    api.text("test",{},{2,2}) --positioned text: {x,y}
    local str=api.input(60,"[Enter string]>:")
    api.text(str)
    api.exit()--or os.exit()
  end
end

--DO NOT EDIT BELOW
local ssap=require("ssap")
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
      if config["log"] then print("Invalid position for text.")
      return false end
    options["x"]=tonumber(position[1])
    options["y"]=tonumber(position[2])
  end
  ssap.send(app.client_ip,{"text",options,text})
end
function api.input(timeoutTime,label)
  local result=ssap.getInput(app.client_ip,timeoutTime,label)
  if not result then --handle timeout
    of config["log"] then print("Timeouted during input") end
    ssap.disconnect(app.client_ip)
    app.shutdown()
  end
  return result
end
function api.exit()
  ssap.disconnect(app.client_ip)
  app.shutdown()
end
local app={}
app.client_ip=""
function app.main(to_ip)
  app.client_ip=to_ip
  application()
end
function app.shutdown()
  if config["log"] then print("Shutting down application '"..config["name"].."' with "..app.client_ip) end
  os.exit()
end
return app