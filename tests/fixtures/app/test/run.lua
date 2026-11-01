local lu = require("luaunit")
local words = require("app.words")

function testCount()
   lu.assertEquals(words.count("the cat and The hat"), { the = 2, cat = 1, ["and"] = 1, hat = 1 })
end

function testEmpty()
   lu.assertEquals(words.count(""), {})
end

os.exit(lu.LuaUnit.run())
