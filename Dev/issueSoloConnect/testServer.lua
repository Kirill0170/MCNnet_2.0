local cmnp=require("cmnp")
local thread=require("thread")
--test
local ip1="48c3:76f8"
local ip2="d34c:148c" --local ips for testing

function serverFunction(ip)
  print("waiting for "..ip)
  local data=cmnp.receive(ip,"test",60)
  print(data[1])
end

thread.create(serverFunction,ip1):detach()
os.sleep(5)
thread.create(serverFunction,ip2):detach()