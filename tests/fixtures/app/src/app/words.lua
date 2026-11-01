local lpeg = require("lpeg")

local words = {}

local word = lpeg.C((lpeg.R("az", "AZ") + lpeg.P("'")) ^ 1)
local gap = (1 - lpeg.R("az", "AZ")) ^ 0
local all = lpeg.Ct(gap * (word * gap) ^ 0)

-- The number of times each word occurs in text, in lower case.
function words.count(text)
   local counted = {}
   for _, w in ipairs(all:match(text)) do
      local key = w:lower()
      counted[key] = (counted[key] or 0) + 1
   end
   return counted
end

return words
