local lib = require("lib")

local demo = {}

function demo.main()
   print(lib.show({ jit = jit and jit.version or "none" }))
end

return demo
