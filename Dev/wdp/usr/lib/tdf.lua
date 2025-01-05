local ver="1.4.7"
local fs=require("filesystem")
local term=require("term")
local gpu=require("component").gpu
local colors={}
colors["text"]={}--minecraft text formatting-like
colors["wool"]={}--minecraft wool&dye order
--text
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
--wool
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
function tdf.util.isTDF(filename)
  return string.match(filename, "%.tdf$") ~= nil
end
TDFfile={}
TDFfile.__index=TDFfile
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
  instance.config["ver"]="unknown"
  instance.config["background"]="0"
  instance.config["foreground"]="F"
  --read
  local prevline=file:read("*l")
  local main=false
  local bgset=false
  local i=0
  --check
  if not prevline then return nil end
  if string.sub(prevline,1,4)~="#tdf" then return nil end
  instance.config["ver"]=tdf.util.splitBy(prevline,":")[2]
  while prevline do
    prevline=file:read("*l")
    if not prevline then break end
    i=i+1
    --function word
    if not main then
      local trimline=tdf.util.trimSpace(prevline)
      if string.sub(trimline,1,1)=="#" then
        trimline=trimline:sub(2)
        local args=tdf.util.splitBy(trimline,":")
        if args[1]=="title" then
          instance.config["title"]=args[2] or "error"
        elseif args[1]=="resolution" then
          local res=tdf.util.splitBy(args[2],"x")
          local x=tonumber(res[1])
          local y=tonumber(res[2])
          if x and y then
            instance.config["resolution"]={x,y}
          end
        elseif args[1]=="main" then
          main=true
          instance.config["main"]=i+1 --start of file
        elseif args[1]=="format" then
          instance.config["format"]=args[2] or "&%"
        elseif args[1]=="colormap" then
          if args[2]=="wool" or args[2]=="text" then
            if args[2]=="text" or args[2]=="wool" then
              instance.config["colormap"]=args[2]
            end
            if not bgset then
              if args[2]=="wool" then
                instance.config["background"]="F"
                instance.config["foreground"]="0"
              end
            end
          end
        elseif args[1]=="background" then
          instance.config["background"]=string.sub(args[2],1,1)
          bgset=true
        elseif args[1]=="foreground" then
          instance.config["foreground"]=string.sub(args[2],1,1)
        end
      end
    end
    table.insert(instance.rawlines,prevline)
  end
  file:close()
  return instance
end
function TDFfile:print(range,offsetY)
  local startLine=0
  local endLine=self.config.resolution[2]
  if type(range)=="table" then
    if #range==2 then
      startLine=range[1]
      endLine=range[2]
      if startLine<0 then startLine=0 end
    end
  end
  if not offsetY then offsetY=1 end
  local y=offsetY+1
  local fg_char=self.config.format:sub(1,1)
  local bg_char=self.config.format:sub(2,2)
  gpu.setForeground(colors[self.config.colormap][self.config.foreground])
  gpu.setBackground(colors[self.config.colormap][self.config.background])
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
          if char==fg_char then gpu.setForeground(colors[self.config.colormap][self.config.foreground])
          else gpu.setBackground(colors[self.config.colormap][self.config.background]) end
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
        term.write(char)
        i=i+1
      end
    end
  end
  --range
  local startLine=self.config.main+startLine
  local endLine=self.config.main+endLine
  if endLine>#self.rawlines then endLine=#self.rawlines end
  --fill
  gpu.setBackground(colors[self.config.colormap][self.config.background])
  gpu.fill(1,offsetY+1,self.config.resolution[1],self.config.resolution[2]," ")
  for l=startLine,endLine do
    term.setCursor(1,y)
    --link
    local check_fg=fg_char
    local check_bg=bg_char
    if fg_char=="%" then check_fg="%%" end
    if bg_char=="%" then check_bg="%%" end
    if string.find(self.rawlines[l],check_fg) or string.find(self.rawlines[l],check_bg) then
      formattedPrint(self.rawlines[l])
    else
      term.write(string.sub(self.rawlines[l],1,self.config.resolution[1]))
    end
    y=y+1
  end
  term.setCursor(1,self.config.resolution[2]+offsetY+1)
  return true
end
function TDFfile:saveAs(savename)
  if not savename then return false end
  local file=io.open(savename,"w")
  if not file then return false end
  file:write("#tdf:"..self.config.ver.."\n")
  for i=1,#self.rawlines do
    file:write(self.rawlines[i].."\n")
  end
  file:close()
  return true
end
function tdf.readFile(filename)
  if not fs.exists(filename) then return nil end
  local file=io.open(filename)
  if not file then return nil end
  return TDFfile:readFile(filename)
end
return tdf