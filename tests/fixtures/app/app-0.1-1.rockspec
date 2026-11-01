rockspec_format = "3.0"
package = "app"
version = "0.1-1"
source = {
   url = "git+https://github.com/nix-purifiers/luarocks-purifier.git",
   tag = "v0.1",
}
description = {
   summary = "A luarocks-purifier test fixture",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
   -- A GitHub archive.
   "inspect == 3.1.3",
   -- A source rock with C code.
   "lpeg == 1.1.0",
   -- A zip archive.
   "argparse == 0.7.1",
   -- A git source with a C library from outside LuaRocks (zlib).
   "lua-zlib == 1.2",
}
test_dependencies = {
   "luaunit == 3.4",
}
build = {
   type = "builtin",
   modules = {
      app = "src/app.lua",
      ["app.words"] = "src/app/words.lua",
   },
   install = {
      bin = {
         app = "bin/app",
      },
   },
}
test = {
   type = "command",
   script = "test/run.lua",
}
