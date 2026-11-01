local greeting = require("greeting")
local inspect = require("inspect")

local lib = {}

-- The table t, shown by both copies of inspect.lua.
function lib.show(t)
   local a, b = greeting(t), inspect(t)
   assert(a == b, "the two copies of inspect.lua disagree")
   return a
end

return lib
