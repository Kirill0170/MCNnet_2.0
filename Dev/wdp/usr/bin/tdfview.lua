--simple tdf viewer
local ver="1.2"
local shell=require("shell")
local component=require("component")
local gpu=component.gpu
local tdf=require("tdf")
local fs=require("filesystem")

local function cprint(text,color)
  gpu.setForeground(color)
  print(text)
  gpu.setForeground(0xFFFFFF)
end

--functions
local function help()
  cprint("TDF-view",0xFFCC33)
  print("Version "..ver)
  print("About: view .tdf file")
  cprint("Usage: tdfview <file.tdf>",0x6699FF)
end

local function view(filename)
  if not filename then cprint("No file given",0xFF0000) return end
  if not fs.exists(filename) then cprint("No such file: "..filename,0xFF0000) return end
  if fs.isDirectory(filename) then cprint("Direcotry given",0xFF0000) return end
  if tdf.util.isTDF(filename) then cprint("You should give .tdf file",0xFF0000) return end
  local tfile=tdf.readFile(filename)
  if not tfile then cprint("Couldn't read file",0xFF0000) return end
  require("term").clear()
  gpu.setBackground(0xCCCCCC)
  gpu.setForeground(0x000000)
  print("  "..tfile.config["title"].."  ")
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  tfile:print(0,1)
end
--main
local args,ops = shell.parse(...)
if not args then help()
elseif ops["h"] or ops["help"] then help()
else view(args[1]) end