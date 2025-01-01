local ver="0.8.1"
local wdp=require("wdp")
local tdf=require("tdf")
local mnp=require("cmnp")
local term=require("term")
local event=require("event")
local shell=require("shell")
local fs=require("filesystem")
local gpu=require("component").gpu

local defaultResolution="80x22"
local defaultColormap="wool"
local defaultBackground="0"

local function printTabBar(tabs,selected)
  gpu.setBackground(0xCCCCCC)
  gpu.setForeground(0x000000)
  local prev_x,prev_y=term.getCursor()
  term.setCursor(1,1)
  term.write("WB ")
  for i=1,#tabs do
    if i==selected then
      local str="["..i.." "..tabs[i].title.."]"
      gpu.setForeground(0x6699FF)
      term.write(str)
      gpu.setForeground(0x000000)
    else
      local str="["..i.." "..tabs[i].title.."]"
      term.write(str)
    end
  end
  local spaceStr=""
  local x,_=term.getCursor()
  for i=x,gpu.getResolution() do
    spaceStr=spaceStr.." "
  end
  term.write(spaceStr)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  term.setCursor(prev_x,prev_y)
  return true
end
local function printAddressBar(url,tfile,override)
  if not override then override="wdp://" end
  if not tfile then return false end
  local x=tfile.config.resolution[1]
  if not x then x=gpu.getResolution()[1] end
  local str=" "..override..url
  while string.len(str)<x do str=str.." " end
  local prev_x,prev_y=term.getCursor()
  term.setCursor(1,2)
  if tfile.config.background~="8" then
    gpu.setBackground(0xCCCCCC) --8
  else
    gpu.setBackground(0xFFFFFF)
  end
  gpu.setForeground(0x000000)
  print(str)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  term.setCursor(prev_x,prev_y)
end
--Tab
Tab={}
Tab.nextId=1
Tab.tabs={}
Tab.selected=1
function getTabIndex(id)
  for i=1,#Tab.tabs do
    if Tab.tabs[i].id==id then return i end
  end
end
function printSelectedTab()
  Tab.tabs[Tab.selected]:print()
end
Tab.__index=Tab
function Tab:new(tfile,url,loc)
  if not tfile then return nil end
  local instance=setmetatable({},Tab)
  instance.title=tfile.config.title
  instance.tfile=tfile
  instance.loc=loc or false
  instance.url=url
  instance.scroll=0
  instance.id=Tab.nextId
  Tab.nextId=Tab.nextId+1
  Tab.selected=#Tab.tabs+1
  table.insert(Tab.tabs,instance)
  return instance
end
function Tab:close()
  local i = getTabIndex(self.id)
  if i==1 then
    if #Tab.tabs==1 then
      --new empty page
      gpu.setBackground(0x000000)
      gpu.setForeground(0xFFFFFF)
      term.clear()
      os.exit()
    else
      Tab.selected=1
    end
  else
    Tab.selected=i-1
  end
  table.remove(Tab.tabs,i)
  printSelectedTab()
end
function Tab:print(scroll) --LOCAL
  if scroll then self.scroll=scroll end
  printTabBar(Tab.tabs,getTabIndex(self.id))
  printAddressBar(self.url,self.tfile,self.loc)
  self.tfile:print(self.scroll,2)
end

local function cprint(text,color)
  gpu.setForeground(color)
  print(text)
  gpu.setForeground(0xFFFFFF)
end
local function createLocalPage(title,lines,filename)
  if not title then title="unknown" end
  if not lines then lines="Browser empty page" end
  if not filename then filename=os.tmpname() end
  local file=io.open(filename,"w")
  file:write("#tdf:"..tdf.ver().."\n#title:"..title.."\n#resolution:"..defaultResolution.."\n")
  file:write("#colormap:"..defaultColormap.."\n#format:%#\n#background:"..defaultBackground.."\n#foreground:F\n#main\n")
  file:write(lines)
  file:close()
  return filename
end
local function clearPage()
  local res=tdf.util.splitBy(defaultResolution,"x")
  local x=tonumber(res[1])
  local y=tonumber(res[2])
  gpu.fill(1,3,x,y," ")
  term.setCursor(1,3)
end
local function errorPage(url,code)
  local error_message="\n        Connection failed\n\n    An error occured while trying to connect to "..url.."\n"
  error_message=error_message.."    Error code: %e "..code.." %r"
  local filename=createLocalPage("Error",error_message)
  local t=Tab:new(tdf.readFile(filename),url)
  t:print()
end
--functions
local function help()
  cprint("WDP Browser",0xFFCC33)
  print("Version "..ver)
  print("Web Document Protocol version: "..wdp.ver())
  print("About: simple WDP GET")
  print("Downloads a webpage via FTP and opens it.")
  print("You can set download filename as second argument")
  print("Else, will be saved at /tmp/")
  cprint("Usage: wb <options> [host/file] <saveAs>",0x6699FF)
  print("Examples:")
  print("wb 12ab:34cd/file.tdf")
  print("wb example.com//etc/man.tdf download.tdf")
end
function newPage()
  clearPage()
  term.setCursor(1,2)
  gpu.setBackground(0xCCCCCC)
  gpu.setForeground(0x000000)
  local spaces=""
  for i=1,80 do spaces=spaces.." " end
  term.write(spaces)
  term.setCursor(2,2)
  local url=io.read()
  gpu.setBackground(0xFFFFFF)
  term.setCursor(1,3)
  print("Connecting..")
  page(url)
end
function page(dest,saveAs)
  if saveAs=="" then saveAs=nil end
  if string.sub(dest,1,6)=="wdp://" then dest=string.sub(dest,7) end
  local hostname,filename=wdp.resolve(dest)
  if hostname=="local" or hostname==os.getenv("this_ip") then
    --local page
    if fs.exists(filename) and fs.isDirectory(filename)==false then
      local tfile=tdf.readFile(filename)
      if not tfile then
        --error
        return false,"TDF_READ_FAIL"
      end
      local t=Tab:new(tfile,filename,"local://")
      t:print()
      return true
    else
      --error page
      return false,"NO_SUCH_FILE"
    end
  end
  if not mnp.isConnected() then cprint("You should be connected to network",0xFF0000) return false end
  local success,code=wdp.get(dest)
  if not success then
    --error
    errorPage(dest,code)
    return false
  else
    local tfile=code
    local t=Tab:new(tfile,dest)
    t:print()
    return true
  end
end
function browser(dest,saveAs)
  if dest then
    page(dest,saveAs)
  end
  while true do
    local id,_,keyA,keyB,scroll=event.pullMultiple("interrupted","key_down","scroll")
    if id=="interrupted" or (id=="key_down" and keyB==16) then
      for _,t in pairs(Tab.tabs) do
        t:close()
      end
      break
    elseif id=="key_down" then
      if keyB==35 then-- h
        page("local//etc/wb/wbhelp.tdf")
      elseif keyB==12 then-- -
        Tab.tabs[Tab.selected]:close()
      elseif keyB==25 then-- p
        printSelectedTab()
      elseif keyB==203 then -- <-
        if Tab.selected>1 then
          Tab.selected=Tab.selected-1
        else
          Tab.selected=#Tab.tabs
        end
        printSelectedTab()
      elseif keyB==205 then -- ->
        if Tab.selected<#Tab.tabs then
          Tab.selected=Tab.selected+1
        else
          Tab.selected=1
        end
        printSelectedTab()
      elseif keyA==43 and keyB==13 then -- +
        newPage()
      elseif keyB==31 then -- s 
        --save
      end
    elseif id=="scroll" then

    end
  end
end
--main

if not fs.exists("/etc/wb") then
  fs.makeDirectory("/etc/wb")
end
if not fs.exists("/etc/wb/wbhelp.tdf") then
  local help_lines=[[
%3 Overview %r
%2 WDP %r (Web Document Protocol) gets server-located %2 TDF %r (Text Document Format) page.
This browser (WB - Wdp Browser) makes it easy to view webpages.

%3 Command usage:%r
%5 wb <url> %r - opens browser with page
%5 wb <url> <saveAs> %r - opens page and saves it as given name

%3 URL %r
URL is a pair of hostname/IPv2 and file address on that server, divided by /
You can open local pages on this computer by using 'local' as hostname
Examples:
12ab:34cd/home.tdf -> ~/home.tdf at 12ab:34cd server
example.com//file.tdf -> /file.tdf at example.com server
local//etc/wb/wbhelp.tdf -> /etc/wb/wbhelp.tdf on this computer (this file)

%3 Keybinds: %r
%9 h %r - open a new tab with this help page
%9 s %r - save as
%9 + %r - new tab
%9 - %r - close tab
%9 p %r - reprint tab
%9 arrows < > %r - navigation between tabs
%9 q or ctrl+c %r - close all and exit
]]
  createLocalPage("Help",help_lines,"/etc/wb/wbhelp.tdf")
end


local args,ops = shell.parse(...)
if not args and not ops then help()
elseif ops["h"] or ops["help"] then help()
elseif args[1]=="help" then
  browser("local//etc/wb/wbhelp.tdf")
elseif not args[1] then
  local connected=mnp.isConnected()
  local local_ip=" - "
  local connct=""
  if connected then
    local_ip=os.getenv("this_ip")
    connct="%5 Connected! %r"
  else
    connct="%e Not connected! %r"
  end
  local home_lines="WDP Browser version "..ver.."\n"
  home_lines=home_lines..[[
Home page

Press h for help
Press + for new tab

%3 Connection status %r
]]
  home_lines=home_lines..connct.."\nLocal IPv2: "..local_ip
  createLocalPage("Home",home_lines,"/etc/wb/wbhome.tdf")
  browser("local//etc/wb/wbhome.tdf")
else browser(args[1],args[2]) end
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
term.clear()