local cmnp=require("cmnp")
local ser=require("serialization")
cmnp.send("d34c:e8b0","test",ser.serialize({"helloworld_1!"}))