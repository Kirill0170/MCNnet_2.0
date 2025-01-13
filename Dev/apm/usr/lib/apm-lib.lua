local ver = "0.2"
local fs = require("filesystem")
local mnp = require("cmnp")
local ftp = require("ftp")
local ser = require("serialization")
local apm = {}

Package = {}
Package.__index = Package
function Package:new(dir)
	local instance = setmetatable({}, Package)
	instance.dir = dir
	--manifest
	if not fs.exists(dir .. "/manifest") then
		return nil
	end
	local manifest = io.open(dir .. "/manifest")
	instance.name = manifest:read("l")
	if not instance.name then
		return nil
	end
	instance.ver = manifest:read("l")
	if not instance.ver then
		return nil
	end
	local line = manifest:read("l")
	instance.files = {}
	if not line then
		return nil
	end --cannot have no packages
	instance.files[1] = line
	while line ~= nil do
		line = manifest:read("l")
		if line then
			table.insert(instance.files, line)
		end
	end
	manifest:close()
	return instance
end
function Package:checkFiles()
	local sum = 0
	for i = 1, #self.files do
		if not fs.exists(self.dir .. self.files[i]) then
			mnp.log("APM", self.dir .. self.files[i] .. " does not exist!", 2)
			return false, 0
		else
			sum = sum + fs.size(self.dir .. self.files[i])
		end
	end
	return true, sum
end
function apm.ver()
	return ver
end
function apm.readPackage(dir)
	if not fs.exists(dir) or not fs.isDirectory(dir) then
		return nil
	end
	if string.sub(dir, -1) == "/" then
		dir = string.sub(dir, 1, -2)
	end
	return Package:new(dir)
end
function apm.sendPackage(to_ip, package)
	mnp.send(to_ip, "apm", { "transmission-start", package.files, package:checkFiles() })
	if not ftp.connection(to_ip) then
		mnp.log("APM", "FTP connection fail with " .. to_ip)
		return false
	end
	mnp.log("APM", "FTP connected with " .. to_ip)
	for i = 1, #package.files do
		ftp.upload(to_ip, package.dir .. package.files[i], false)
	end
	ftp.endConnection(to_ip)
	return true
end
function apm.getInfo(server_ip, name)
	if not require("ipv2").isIPv2(server_ip) or not name then
		return nil, "arg fault"
	end
	mnp.send(server_ip, "apm", { "get-info" })
	local rdata = mnp.receive(server_ip, "apm", 15)
	if not rdata then
		return nil, "timeout"
	end
	if rdata[1] == "info" then
		return rdata[2], rdata[3]
	elseif rdata[1] == "not found" then
		return nil, "not found"
	end
	return nil, "unknown"
end
function apm.getPacket(server_ip, name, pretty)
	if not require("ipv2").isIPv2(server_ip) or not name then
		return false
	end
	local function cprint(text, color)
		local gpu = require("component").gpu
		gpu.setForeground(color)
		print(text)
		gpu.setForeground(0xFFFFFF)
	end
	mnp.send(server_ip, "apm", { "get-package", name }, true)
	local rdata = mnp.receive(server_ip, "apm", 15)
	if not rdata then
		return false, "mnp-timeout"
	end
	if rdata[1] == "transmission-start" then
		local files = rdata[2]
		local size = rdata[3]
		--confirm size(maybe get-info?)
		if not ftp.serverConnectionAwait(server_ip, 15) then
			return false, "ftp-timeout"
		end
		if pretty then
			cprint("Connected FTP with " .. server_ip, 0x33CC33)
			cprint(">>Downloading " .. #files .. " files", 0xFFFF33)
		end
		for i = 1, #files do
			local fdata = mnp.receive(server_ip, "ftp", 15)
			if fdata[1] == "put" then
				local filename = fdata[3][1]
				if not filename then
					mnp.log("APM", "Failed to fetch filename of packet: ", 2)
				else
					if pretty then
						cprint(">>Getting " .. files[i], 0xFFFF33)
					end
					ftp.get(server_ip, filename, files[i], pretty)
				end
			else
				--invalid
			end
		end
	else
		return false
	end
end
function apm.server(packageDir)
	if not packageDir then
		packageDir = "/"
	end
	mnp.log("APM", "Starting source server")
	mnp.log("APM", "Reading source packages at " .. packageDir)
	local packages = {}
	for dir in fs.list(packageDir) do
		dir = fs.concat(packageDir, dir)
		local p = Package:new(dir)
		if not p then
			mnp.log("APM", "Failed to read package " .. dir, 2)
		else
			mnp.log("APM", "Package " .. p.name .. " version " .. p.ver)
			packages[p.name] = p
		end
	end
	local thread = require("thread")
	local event = require("event")
	local stopEvent = "apmStop"
	local dataEvent = "apmData"
	thread.create(mnp.listen, "broadcast", "apm", stopEvent, dataEvent):detach()
	while true do
		local id, rdata, from_ip = event.pullMultiple(dataEvent, "interrupted")
		if id == "interrupted" then
			require("computer").pushSignal(stopEvent)
			break
		else
			rdata = ser.unserialize(rdata)
			if rdata[1] == "get-info" then
				local name = rdata[2]
				if packages[name] then
					mnp.send(from_ip, "apm", { "info", packages[name].ver, packages[name]:checkFiles() })
				else
					mnp.send(from_ip, "apm", { "not found" })
				end
			elseif rdata[1] == "get-package" then
				local name = rdata[2]
				if type(name) ~= "string" then
					mnp.log("APM", "Received not a string as packet name. Nice.", 2)
				else
					if packages[name] then
						apm.sendPackage(from_ip, packages[name])
					else
						mnp.send(from_ip, "apm", { "not found" })
					end
				end
			end
		end
	end
end
return apm
