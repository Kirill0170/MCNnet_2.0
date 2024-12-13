--[[
  SSAP FTP APPLICATION

  Your application is down below.
  DO NOT EDIT ANYTHING ELSE, unless you know what you
  are doing.

  configure your application in CONFIG section.
]]
--CONFIG
local config={}
config["name"]="flies-server" --your application name
config["log"]=true --log stuff
config["directory"]="/home/share/"
config["strict"]=true

local styles={} -- configure styles here
styles["error"]={} --red text
styles["error"]["fg_color"]="0xFF0000"
styles["reset"]={}
styles["reset"]["bg_color"]="0x000000"
styles["reset"]["fg_color"]="0xFFFFFF"

--DO NOT EDIT BELOW
local ssap=require("ssap")
local fs=require("filesystem")
local ftp=require("ftp")
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
    if type(text)=="string" then text={text} end
    ssap.send(to_ip,{"text",options,text})
  end
  function api.input(timeoutTime,label)
    local result=ssap.server.getInput(to_ip,timeoutTime,label)
    if not result then --handle timeout
      if config["log"] then print("Timeouted during input") end
      ssap.disconnect(to_ip)
      app.shutdown()
    end
    return result
  end
  function api.keyPress(timeoutTime,only)
    local result=ssap.server.getKeyPress(to_ip,timeoutTime,only)
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
  local sfs={}
  sfs.pwd=config["directory"]
  sfs.workdir=config["directory"]
  sfs.strict=config["strict"]
  sfs.cmd={}
  function sfs.isSubdir(givenDir)
    -- Normalize paths by removing trailing slashes
    local normalizedRoot = sfs.workdir:gsub("/+$", "")
    local normalizedGivenDir = givenDir:gsub("/+$", "")
    if normalizedGivenDir:sub(1, #normalizedRoot) == normalizedRoot then
        return true -- It is a subdirectory
    else
        return false -- It is not a subdirectory
    end
  end
  function sfs.split(inputString)
    local words = {}
    for word in string.gmatch(inputString, "%S+") do
        table.insert(words, word)
    end
    return words
  end
  function sfs.cmd.help()
    local help_message={
      "Current commands are available:",
      "ls <dir> - get contents of dir",
      "get <file> - get file",
      "put <localfile> - put a file to server"
    }
    api.text(help_message)
  end
  function sfs.cmd.ls(dir)
    local list={}
    local list_dir=dir
    if not list_dir or list_dir=="" then list_dir=sfs.pwd end
    print(tostring(list_dir))
    if fs.exists(list_dir) then
      if fs.isDirectory(list_dir) then
        if sfs.strict then
          if not sfs.isSubdir(list_dir) then
            api.text("You can only work in "..sfs.workdir.." directory.",styles["error"])
            return
          end
        end
        for i in fs.list(list_dir) do table.insert(list,i) end
        local stringlist={}
        local c=1
        local str=""
        for i=1,#list do
          if c==6 then
            c=1
            table.insert(stringlist,str)
            str=""
          end
          c=c+1
          str=str.." "..list[i]
        end
        table.insert(stringlist,str)
        api.text(stringlist)
      else
        api.text("Not a directory: "..list_dir,styles["error"])
      end
    else
      api.text("No such directory: "..list_dir,styles["error"])
    end
  end
  function sfs.checkDir(dir)
    if fs.exists(dir) then
      if fs.isDirectory(dir) then
        if sfs.strict then
          if not sfs.isSubdir(dir) then
            api.text("You can only work in "..sfs.workdir.." directory.",styles["error"])
            return false
          end
        end
        return true
      else
        api.text("Not a directory: "..dir,styles["error"])
      end
    else
      api.text("No such directory: "..dir,styles["error"])
    end
    return false
  end
  function sfs.cmd.get(file)
    if fs.exists(file) then
      if fs.isDirectory(file)==false then
        if sfs.strict then
          if not sfs.isSubdir(file) then
            api.text("You can only work in "..sfs.workdir.." directory.",styles["error"])
            return
          end
        end
        ssap.server.sendFile(to_ip,file,true)
      else
        api.text(file.." is a direcotry!",styles["error"])
      end
    else
      api.text("No such file: "..file,styles["error"])
    end
  end
  function sfs.cmd.put(file)
    ssap.server.requestFile(to_ip,file)
  end
  -----EDIT HERE YOUR APPLICATION---------
  if config["log"] then print("Application started") end
  local greet_message={
  "███ ███████ ██ ██      ███████ ███████ ███",
  "██  ██      ██ ██      ██      ██       ██ ",
  "██  █████   ██ ██      █████   ███████  ██ ",
  "██  ██      ██ ██      ██           ██  ██",
  "███ ██      ██ ███████ ███████ ███████ ███ ",
  ">>Welcome!",
  ">>Enter help for help",
  ">>Your current working directory is "..config["directory"]
  }
  api.text(greet_message)
  local pwd=config["directory"]
  while true do --main loop(You don't want your application to finish, right?)
    local str=api.input(60,"[FTP]:"..pwd.." # ")
    if str=="q" or str=="exit" then
      api.exit()--or os.exit()
      break
    elseif str=="" then
    else
      local args=sfs.split(str)
      if args[1]=="pwd" then api.text(pwd)
      elseif args[1]=="ls" then sfs.cmd.ls(args[2])
      elseif args[1]=="help" then sfs.cmd.help()
      elseif args[1]=="get" then sfs.cmd.get(args[2])
      elseif args[1]=="put" then sfs.cmd.put(args[2])
      else api.text("No such command!",styles["error"])
      end
    end
  end
  -----DO NOT EDIT BELOW------:)---------
end
return app