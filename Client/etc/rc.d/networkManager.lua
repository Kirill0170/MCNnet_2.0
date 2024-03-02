local thread=require("thread")
local cmnp=require("cmnp")

function mncp()
  cmnp.mncpCliService()
end

function start()
  mnp.openPorts(true)
  thread.create(mncp):detach()
end

function stop()
  cmnp.disconnect()
end