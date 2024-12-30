local ver="1.2"
local fs=require("filesystem")
local term=require("term")
local gpu=require("component").gpu
local colors={}
colors["text"]={}--minecraft text formatting-like
colors["wool"]={}--minecraft wool&dye order

colors["text"]["0"]=0x000000 --black    
colors["text"]["1"]=0x333399 --darkblue
colors["text"]["2"]=0x336600 --darkgreen
colors["text"]["3"]=0x336699 --cyan
colors["text"]["4"]=0x663300  --brown
colors["text"]["5"]=0x9933CC --purple
colors["text"]["6"]=0xFFCC33 --gold
colors["text"]["7"]=0xCCCCCC --gray
colors["text"]["8"]=0x333333 --darkgray
colors["text"]["9"]=0x6699FF --blue
colors["text"]["A"]=0x33CC33 --green
colors["text"]["B"]=0xFF6699 --aqua
colors["text"]["C"]=0xFF0000 --red
colors["text"]["D"]=0xCC66CC --magenta
colors["text"]["E"]=0xFFFF33 --yellow
colors["text"]["F"]=0xFFFFFF --white

colors["wool"]["0"]=0xFFFFFF --white
colors["wool"]["1"]=0xFFCC33 --gold
colors["wool"]["2"]=0xCC66CC --magenta
colors["wool"]["3"]=0x6699FF --lightblue
colors["wool"]["4"]=0xFFFF33 --yellow
colors["wool"]["5"]=0x33CC33 --lime
colors["wool"]["6"]=0xFF6699 --pink
colors["wool"]["7"]=0x333333 --darkgray
colors["wool"]["8"]=0xCCCCCC --lightgray
colors["wool"]["9"]=0x336699 --cyan
colors["wool"]["A"]=0x9933CC --purple
colors["wool"]["B"]=0x333399 --darkblue
colors["wool"]["C"]=0x663300 --brown
colors["wool"]["D"]=0x336600 --darkgreen
colors["wool"]["E"]=0xFF3333 --red
colors["wool"]["F"]=0x000000 --black
local tdf={}
function tdf.ver() return ver end
tdf.util={}
TDFfile={}
TDFfile.__index=TDFfile
function tdf.util.trimSpace(str)
  return string.match(str,"^%s*(.*)")
end
function tdf.util.splitBy(str,s)
  local res={}
  for i in str:gmatch("([^"..s.."]+)") do
    table.insert(res,i)
  end
  return res
end
function TDFfile:readFile(filename)
  local file=io.open(filename)
  if not file then return nil end
  local instance=setmetatable({},TDFfile)
  instance.rawlines={}
  instance.config={}
  instance.config["title"]="unknown"
  instance.config["resolution"]={80,20}
  instance.config["main"]=1
  instance.config["format"]="&%"
  instance.config["colormap"]="text"
  --read
  local prevline=""
  local main=false
  local i=0
  while prevline do
    prevline=file:read("*l")
    if not prevline then break end
    i=i+1
    --function word
    if not main then
      local trimline=tdf.util.trimSpace(prevline)
      if string.sub(trimline,1,1)=="#" then
        trimline=trimline:sub(2)
        local f_args=tdf.util.splitBy(trimline,":")
        if f_args[1]=="title" then
          instance.config["title"]=f_args[2] or "error"
        elseif f_args[1]=="resolution" then
          local f_res=tdf.util.splitBy(f_args[2],"x")
          local x=tonumber(f_res[1])
          local y=tonumber(f_res[2])
          if x and y then
            instance.config["resolution"]={x,y}
          end
        elseif f_args[1]=="main" then
          main=true
          instance.config["main"]=i+1 --start of file
        elseif f_args[1]=="format" then
          instance.config["format"]=f_args[2] or "&%"
        elseif f_args[1]=="colormap" then
          if f_args[2]=="wool" or f_args[2]=="text" then
            instance.config["colormap"]=f_args[2]
          end
        end
      end
    end
    table.insert(instance.rawlines,prevline)
  end
  return instance
end
function TDFfile:print(offsetY)
  local y=1
  if offsetY then y=1+offsetY end
  local default_fg=gpu.getForeground()
  local default_bg=gpu.getBackground()
  local fg_char=self.config.format:sub(1,1)
  local bg_char=self.config.format:sub(2,2)
  local function formattedPrint(line)
    local i=1
    while i<=#line do
      local char=line:sub(i,i)
      local skip=0
      if char==fg_char or char==bg_char then
        local nextChar=line:sub(i+1,i+1)
        if line:sub(i+2,i+2)==" " then skip=1 end
        if nextChar==fg_char or nextChar==bg_char then
          term.write(nextChar)
          i=i+2
        elseif nextChar=="r" then
          if char==fg_char then gpu.setForeground(default_fg)
          else gpu.setBackground(default_bg) end
          i=i+2+skip
        else
          if nextChar:match("%l") then nextChar=string.upper(nextChar) end
          local col=colors[self.config.colormap][nextChar]
          if col then
            if char==fg_char then gpu.setForeground(col)
            else gpu.setBackground(col) end
          end
          i=i+2+skip
        end
      else
        io.write(char)
        i=i+1
      end
    end
  end
  for l=self.config.main,#self.rawlines do
    term.setCursor(1,y)
    --link
    formattedPrint(self.rawlines[l])
    y=y+1
  end
end
function tdf.readFile(filename)
  if not fs.exists(filename) then return nil end
  local file=io.open(filename)
  if not file then return nil end
  return TDFfile:readFile(filename)
end
return tdf
