local argparse = require("argparse")
local inspect = require("inspect")
local zlib = require("zlib")
local words = require("app.words")

local app = {}

function app.main(args)
   local parser = argparse("app", "A luarocks-purifier test fixture")
   parser:argument("text", "The text to count words in")
   local parsed = parser:parse(args)
   local counted = words.count(parsed.text)
   local packed = zlib.deflate()(parsed.text, "finish")
   local unpacked = zlib.inflate()(packed)
   assert(unpacked == parsed.text, "zlib round trip failed")
   print(inspect(counted))
end

return app
